import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama içi satın alma servisi (Pro / Ömür Boyu mod).
///
/// ÖNEMLİ: `proLifetimeId` değeri Play Console'da (Monetization > Products >
/// In-app products) tanımladığınız gerçek ürün ID'si ile BİREBİR eşleşmelidir,
/// aksi halde `queryProductDetails` boş dönüp satın alma butonu çalışmaz.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  // TODO: Play Console'da tanımladığınız ürün ID'si farklıysa burayı güncelleyin.
  static const String proLifetimeId = 'kar_hesaplayici_pro_lifetime'; // YOUR_IAP_LIFETIME_PRODUCT_ID_HERE
  static const Set<String> productIds = {proLifetimeId};

  static const String _prefsProKey = 'is_pro_user';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final StreamController<bool> _proStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get proStatusStream => _proStatusController.stream;

  List<ProductDetails> products = [];

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    final response = await _iap.queryProductDetails(productIds);
    products = response.productDetails;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );
  }

  /// Cihazda daha önce kaydedilmiş Pro durumunu okur (SharedPreferences).
  /// Uygulama her açıldığında PremiumProvider bu değeri okuyarak reklam/PDF
  /// kapılarını (banner, geçiş reklamı, ödüllü reklam) buna göre ayarlar.
  Future<bool> isProUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsProKey) ?? false;
  }

  Future<void> buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    // Ömür boyu (tek seferlik, tüketilmeyen) satın alma.
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setProStatus(true);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          // Hata/iptal durumunda Pro açılmaz; UI katmanı kendi hata mesajını
          // gösterebilir (bkz. home_screen.dart _buyLifetime).
          break;
        case PurchaseStatus.pending:
          break;
      }
      // Google Play kuyruğunda bekleyen işlemi temizlemek için, durum ne
      // olursa olsun (başarı/hata/iptal) pending purchase tamamlanmalıdır.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _setProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsProKey, isPro);
    _proStatusController.add(isPro);
  }

  void dispose() {
    _subscription?.cancel();
    _proStatusController.close();
  }
}
