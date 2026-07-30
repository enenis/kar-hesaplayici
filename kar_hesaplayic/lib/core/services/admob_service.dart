import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob entegrasyonu — PRODUCTION (yayın) ID'leri ile yapılandırılmıştır.
///
/// ÖNEMLİ: Aşağıdaki ID'ler gerçek AdMob hesabına aittir ve gerçek gelir
/// üretir. Google Play politikaları gereği kendi test cihazınızı AdMob
/// panelinden "Test Cihazı" olarak eklemeden gerçek reklamlara kendi
/// tıklamalarınızla etkileşmeyin (hesabınızın askıya alınmasına yol açabilir).
///
/// NOT: Geçiş reklamı (Interstitial) desteği bilerek kaldırıldı. Ödüllü
/// reklam birimi AdMob panelindeki "Rewarded Interstitial" formatıyla tam
/// uyumlu olması için `RewardedInterstitialAd` sınıfı kullanılır (klasik
/// `RewardedAd` DEĞİL).
///
/// GÜVENİLİRLİK MİMARİSİ (bu sürümde eklendi):
/// - Hem Banner hem Ödüllü Reklam, `onAdFailedToLoad` durumunda OTOMATİK
///   olarak üstel geri çekilmeli (exponential backoff) yeniden deneme yapar
///   (5 sn -> 10 sn -> 20 sn -> 40 sn -> en fazla 60 sn'de sabitlenir).
///   Google'ın kendi önerisi de budur: sabit/çok sık yeniden deneme,
///   isteklerin reddedilmesine (rate limiting) yol açabilir.
/// - Banner durumu bir `Stream<bool>` (`bannerStatusStream`) ile dışa açılır;
///   UI katmanı (`home_screen.dart`) bu akışı dinleyerek reklam alanını
///   yüklenmediğinde TAMAMEN gizler (boş/çirkin bir alan bırakmaz).
class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  // --- BANNER ---
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  int _bannerRetryAttempt = 0;
  Timer? _bannerRetryTimer;

  final StreamController<bool> _bannerStatusController =
      StreamController<bool>.broadcast();

  /// `true`: banner yüklü ve gösterilebilir. `false`: yüklü değil / başarısız
  /// oldu (bu durumda UI, reklam alanını tamamen gizlemelidir).
  Stream<bool> get bannerStatusStream => _bannerStatusController.stream;
  bool get isBannerLoaded => _bannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

  // --- REWARDED INTERSTITIAL ---
  RewardedInterstitialAd? _rewardedAd;
  bool _rewardedReady = false;
  int _rewardedRetryAttempt = 0;
  Timer? _rewardedRetryTimer;

  /// Kullanıcı "PDF İndir"e bastığında, reklam henüz yüklenmemişse en fazla
  /// bu kadar beklenir. Bu süre içinde reklam hazır olmazsa kullanıcı
  /// bekletilmez — PDF doğrudan (reklamsız) oluşturulur.
  static const Duration _loadWaitTimeout = Duration(seconds: 5);

  /// Reklam GÖSTERİLDİKTEN sonra (kullanıcı izlerken) SDK geri çağrımlarının
  /// (dismiss/fail) hiç tetiklenmediği son derece nadir bir uç durumda dahi
  /// sonsuza kadar beklenmemesi için uygulanan geniş güvenlik üst sınırı.
  static const Duration _watchSafetyTimeout = Duration(seconds: 60);

  static const Duration _initSafetyTimeout = Duration(seconds: 10);

  /// Yeniden deneme (retry) gecikmesi — üstel geri çekilme: 5, 10, 20, 40,
  /// sonrasında 60 sn'de sabitlenir. [attempt] 1'den başlar.
  Duration _retryDelay(int attempt) {
    final seconds = 5 * (1 << (attempt - 1).clamp(0, 3)); // 5,10,20,40
    return Duration(seconds: seconds.clamp(5, 60));
  }

  /// Tüm reklam isteklerinde kullanılan, optimize edilmiş ortak `AdRequest`.
  /// Google'ın önerisi: gereksiz/eksik alanlarla dolu bir istek yerine sade
  /// tutmak (SDK zaten cihaz/uygulama bağlamını otomatik ekler); istersen
  /// ileride hedefleme için `keywords` veya `contentUrl` ekleyebilirsiniz.
  static const AdRequest _adRequest = AdRequest();

  // --- REKLAM BİRİMİ ID'LERİ (PRODUCTION) ---
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1728552296743540/3212034963';
    }
    // YOUR_ADMOB_IOS_BANNER_ID_HERE
    return 'ca-app-pub-3940256099942544/2934735716'; // iOS: şimdilik Google TEST ID
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1728552296743540/2230125786';
    }
    // YOUR_ADMOB_IOS_REWARDED_ID_HERE
    return 'ca-app-pub-3940256099942544/1712485313'; // iOS: şimdilik Google TEST ID
  }

  /// AndroidManifest.xml / Info.plist içine eklenmesi gereken uygulama ID'si.
  static const String admobAppId = 'ca-app-pub-1728552296743540~6851897078';

  /// NOT: Bu metod `main.dart` tarafından `await` EDİLMEDEN, arka planda
  /// çağrılır. Ne kadar sürerse sürsün uygulamanın açılışını ETKİLEMEZ.
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize().timeout(_initSafetyTimeout);
      _loadRewarded();
    } catch (_) {
      // Reklamlar bu oturumda pasif kalır; uygulamanın diğer özellikleri etkilenmez.
    }
  }

  // ======================= BANNER =======================

  /// Banner reklamı yükler. `initState`'ten en yüksek öncelikle, hemen
  /// çağrılması amaçlanmıştır (bkz. home_screen.dart). Başarısız olursa
  /// otomatik olarak (üstel geri çekilmeyle) kendini yeniden dener —
  /// çağıran tarafın tekrar bu metodu çağırmasına GEREK YOKTUR.
  void loadBanner() {
    _bannerRetryTimer?.cancel();

    final ad = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: _adRequest,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _bannerRetryAttempt = 0; // başarı sonrası sayaç sıfırlanır
          _bannerStatusController.add(true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerLoaded = false;
          _bannerStatusController.add(false);
          debugPrint('Banner reklam yüklenemedi (deneme #$_bannerRetryAttempt): $error');
          _scheduleBannerRetry();
        },
      ),
    )..load();

    _bannerAd = ad;
  }

  void _scheduleBannerRetry() {
    _bannerRetryAttempt++;
    _bannerRetryTimer = Timer(_retryDelay(_bannerRetryAttempt), loadBanner);
  }

  void disposeBanner() {
    _bannerRetryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerLoaded = false;
  }

  // ======================= REWARDED INTERSTITIAL =======================

  void _loadRewarded() {
    _rewardedRetryTimer?.cancel();

    RewardedInterstitialAd.load(
      adUnitId: rewardedAdUnitId,
      request: _adRequest,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedReady = true;
          _rewardedRetryAttempt = 0; // başarı sonrası sayaç sıfırlanır
        },
        onAdFailedToLoad: (error) {
          _rewardedReady = false;
          _rewardedAd = null;
          debugPrint('Ödüllü reklam yüklenemedi (deneme #$_rewardedRetryAttempt): $error');
          _scheduleRewardedRetry();
        },
      ),
    );
  }

  void _scheduleRewardedRetry() {
    _rewardedRetryAttempt++;
    _rewardedRetryTimer = Timer(_retryDelay(_rewardedRetryAttempt), _loadRewarded);
  }

  Future<bool> _waitUntilReady(Duration timeout) async {
    if (_rewardedReady && _rewardedAd != null) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_rewardedReady && _rewardedAd != null) return true;
    }
    return _rewardedReady && _rewardedAd != null;
  }

  /// Ödüllü reklamı gösterir (PDF indirme/kaydetme öncesi).
  ///
  /// AKIŞ (kesin sıra):
  /// 1. Reklam hazır değilse en fazla [_loadWaitTimeout] (5 sn) beklenir.
  ///    Bu sürede hazır olmazsa [onFailedOrUnavailable] çağrılır — kullanıcı
  ///    bekletilmeden PDF doğrudan oluşturulur (arka planda otomatik yeniden
  ///    deneme mekanizması bir sonraki seferde reklamı hazır tutmaya çalışır).
  /// 2. Reklam gösterilir. `onUserEarnedReward` SDK geri çağrımı yalnızca
  ///    bir BAYRAK (`rewardEarned`) set eder — PDF'i BURADA TETİKLEMEZ.
  /// 3. Asıl tetikleme, reklam TAMAMEN kapandıktan SONRA, yani
  ///    `onAdDismissedFullScreenContent` içinde `complete()` çağrıldıktan
  ///    sonra gerçekleşir.
  /// 4. `.show()` beklenmedik bir istisna fırlatırsa veya
  ///    `onAdFailedToShowFullScreenContent` tetiklenirse, kullanıcı mağdur
  ///    edilmez — [onFailedOrUnavailable] ile PDF doğrudan oluşturulur.
  Future<void> showRewardedAd({
    required Future<void> Function() onUserEarnedReward,
    required Future<void> Function() onFailedOrUnavailable,
    Future<void> Function()? onDismissedWithoutReward,
  }) async {
    // 1) Reklam hazır değilse kısa bir süre (en fazla 5 sn) yüklenmesini bekle.
    if (!_rewardedReady || _rewardedAd == null) {
      final becameReady = await _waitUntilReady(_loadWaitTimeout);
      if (!becameReady || _rewardedAd == null) {
        await onFailedOrUnavailable();
        return;
      }
    }

    final ad = _rewardedAd!;
    bool rewardEarned = false;
    bool failedToShow = false;

    final completer = Completer<void>();
    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedReady = false;
        _rewardedAd = null;
        _loadRewarded(); // sıradaki için önceden yükle (retry mantığı dahil)
        complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedReady = false;
        _rewardedAd = null;
        _loadRewarded();
        failedToShow = true;
        complete();
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          rewardEarned = true;
        },
      );
    } catch (_) {
      _rewardedReady = false;
      _rewardedAd = null;
      failedToShow = true;
      complete();
    }

    await completer.future.timeout(_watchSafetyTimeout, onTimeout: complete);

    if (failedToShow) {
      await onFailedOrUnavailable();
    } else if (rewardEarned) {
      await onUserEarnedReward();
    } else {
      await (onDismissedWithoutReward ?? onFailedOrUnavailable).call();
    }
  }

  /// Servis tamamen kapatılırken (örn. uygulama sonlanırken) çağrılabilir;
  /// bekleyen retry zamanlayıcılarını temizler.
  void dispose() {
    _bannerRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    _bannerStatusController.close();
  }
}
