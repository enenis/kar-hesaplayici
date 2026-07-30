import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/services/admob_service.dart';
import '../core/services/iap_service.dart';
import '../providers/premium_provider.dart';
import 'tabs/ecommerce_tab.dart';
import 'tabs/export_tab.dart';
import 'tabs/freelancer_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _bannerLoaded = false;
  StreamSubscription<bool>? _bannerStatusSub;

  final _tabs = const [EcommerceTab(), FreelancerTab(), ExportTab()];

  @override
  void initState() {
    super.initState();
    // google_mobile_ads Android/iOS/masaüstüne özeldir; web'de (FlutLab web
    // emülatörü dahil) çalışma zamanı hatası verebileceğinden bilerek atlanır.
    if (!kIsWeb) {
      // Mevcut durumu hemen yansıt (servis daha önce başka bir ekrandan
      // yüklenmiş olabilir), sonra akışı dinlemeye devam et. Yükleme
      // başarısız olursa AdMobService kendi içinde otomatik olarak (üstel
      // geri çekilmeyle) yeniden dener — bu ekranın tekrar tetiklemesine
      // gerek yoktur, sadece `isAdLoaded` durumunu yansıtır.
      _bannerLoaded = AdMobService.instance.isBannerLoaded;
      _bannerStatusSub = AdMobService.instance.bannerStatusStream.listen((loaded) {
        if (mounted) setState(() => _bannerLoaded = loaded);
      });
      // Banner reklamı EN YÜKSEK ÖNCELİKLE, initState'in ilk işi olarak
      // yüklenmeye başlar.
      if (!_bannerLoaded) {
        AdMobService.instance.loadBanner();
      }
    }
  }

  @override
  void dispose() {
    _bannerStatusSub?.cancel();
    // NOT: `AdMobService.instance.disposeBanner()` BİLEREK burada çağrılmıyor.
    // Banner, uygulama genelinde tek bir servis örneğinde yaşar; bu ekran
    // (HomeScreen) yeniden oluşturulsa bile reklamın/retry döngüsünün devam
    // etmesi istenir. Uygulama tamamen kapanırken zaten process sonlanır.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<PremiumProvider>().isPro;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kâr / Komisyon / Desi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!isPro)
            TextButton.icon(
              onPressed: () => _showProSheet(context),
              icon: const Icon(Icons.workspace_premium, color: AppColors.secondary),
              label: const Text('Pro', style: TextStyle(color: AppColors.secondary)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: IndexedStack(index: _index, children: _tabs)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // isAdLoaded kontrolü: banner yüklenmediyse (henüz yüklenmedi,
            // başarısız oldu, ağ yok vb.) hiçbir alan AYRILMAZ — kullanıcıya
            // boş/çirkin bir boşluk gösterilmez. Yalnızca gerçekten yüklü
            // olduğunda (isAdLoaded == true) banner'ın kendi boyutu kadar yer
            // kaplar. Yalnızca ücretsiz kullanıcılarda gösterilir.
            if (!isPro && _bannerLoaded && AdMobService.instance.bannerAd != null)
              SizedBox(
                width: AdMobService.instance.bannerAd!.size.width.toDouble(),
                height: AdMobService.instance.bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: AdMobService.instance.bannerAd!),
              ),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'E-Ticaret',
                ),
                NavigationDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge),
                  label: 'Freelancer',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'Döviz / İhracat',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ProPaywallSheet(),
    );
  }
}

class _ProPaywallSheet extends StatefulWidget {
  const _ProPaywallSheet();

  @override
  State<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<_ProPaywallSheet> {
  bool _isPurchasing = false;
  bool _isRestoring = false;

  /// Play Console'da tanımlı ürünün gerçek fiyatını (mağazadan çekilen)
  /// gösterir; ürün henüz yüklenmediyse (örn. ilk açılış anı) yaklaşık
  /// referans fiyat olarak "29,99 TL" gösterilir.
  String get _priceLabel {
    final match = IapService.instance.products
        .where((p) => p.id == IapService.proLifetimeId);
    if (match.isNotEmpty) return match.first.price;
    return '29,99 TL';
  }

  Future<void> _buyLifetime() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      final match = IapService.instance.products
          .where((p) => p.id == IapService.proLifetimeId);
      if (match.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ürün bilgisi yükleniyor, birazdan tekrar deneyin.'),
            ),
          );
        }
        return;
      }
      await IapService.instance.buy(match.first);
      // Satın alma sonucu IapService.purchaseStream üzerinden asenkron
      // olarak gelir ve PremiumProvider bunu otomatik yakalayıp isPro'yu
      // günceller (bkz. providers/premium_provider.dart) — bu ekranın
      // sonucu beklemesine gerek yoktur.
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma işlemi başlatıldı...')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma başlatılamadı. Lütfen tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      await IapService.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alımlar geri yükleniyor...')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geri yükleme başarısız oldu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.workspace_premium, color: AppColors.secondary, size: 28),
                SizedBox(width: 10),
                Text('Pro\'ya Geç', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            const _ProFeatureRow(text: 'Reklamsız deneyim (alt banner kapanır)'),
            const _ProFeatureRow(text: 'PDF indirmede ödüllü reklam izleme zorunluluğu kalkar'),
            const _ProFeatureRow(text: 'Sınırsız senaryo/hesaplama kaydetme'),
            const _ProFeatureRow(text: 'Özel logo / firma adı ekleme'),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isPurchasing ? null : _buyLifetime,
                child: _isPurchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Ömür Boyu Pro — $_priceLabel'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isRestoring ? null : _restore,
                child: _isRestoring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Satın Alımları Geri Yükle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final String text;
  const _ProFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
