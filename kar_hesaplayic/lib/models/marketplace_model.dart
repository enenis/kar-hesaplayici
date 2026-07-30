enum Marketplace { trendyol, hepsiburada, n11, amazonTr, ownSite }

extension MarketplaceX on Marketplace {
  String get label {
    switch (this) {
      case Marketplace.trendyol:
        return 'Trendyol';
      case Marketplace.hepsiburada:
        return 'Hepsiburada';
      case Marketplace.n11:
        return 'N11';
      case Marketplace.amazonTr:
        return 'Amazon TR';
      case Marketplace.ownSite:
        return 'Shopify / Kendi Sitem';
    }
  }

  /// Genel kategori ortalaması olarak kabul edilen varsayılan komisyon oranı (%).
  /// Kullanıcı bu değeri her zaman manuel değiştirebilir; gerçek oranlar
  /// kategoriye göre değişiklik gösterebileceğinden bilgilendirme amaçlıdır.
  double get defaultCommissionRate {
    switch (this) {
      case Marketplace.trendyol:
        return 18.0;
      case Marketplace.hepsiburada:
        return 17.0;
      case Marketplace.n11:
        return 15.0;
      case Marketplace.amazonTr:
        return 15.0;
      case Marketplace.ownSite:
        return 2.5; // ödeme altyapısı komisyonu (iyzico/PayTR benzeri)
    }
  }
}
