import 'marketplace_model.dart';

/// Kaydedilen bir e-ticaret hesaplama senaryosu (Pro özellik: sınırsız kayıt).
/// Kullanıcının o an ekrandaki TÜM girdilerini saklar ki liste üzerinden
/// tıklandığında hesaplama ekranı birebir aynı şekilde geri yüklenebilsin.
class SavedCalculation {
  final String id;
  final String title;
  final DateTime createdAt;
  final double buyPrice;
  final double sellPrice;
  final Marketplace marketplace;
  final double commissionRatePercent;
  final double shippingCost;
  final double vatRatePercent;
  final double extraCost;
  final double netProfit;
  final double roiPercent;

  SavedCalculation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.buyPrice,
    required this.sellPrice,
    required this.marketplace,
    required this.commissionRatePercent,
    required this.shippingCost,
    required this.vatRatePercent,
    this.extraCost = 0,
    required this.netProfit,
    required this.roiPercent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'marketplace': marketplace.name,
        'commissionRatePercent': commissionRatePercent,
        'shippingCost': shippingCost,
        'vatRatePercent': vatRatePercent,
        'extraCost': extraCost,
        'netProfit': netProfit,
        'roiPercent': roiPercent,
      };

  factory SavedCalculation.fromJson(Map<String, dynamic> json) {
    return SavedCalculation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      buyPrice: (json['buyPrice'] as num).toDouble(),
      sellPrice: (json['sellPrice'] as num).toDouble(),
      marketplace: Marketplace.values.firstWhere(
        (m) => m.name == json['marketplace'],
        orElse: () => Marketplace.trendyol,
      ),
      commissionRatePercent: (json['commissionRatePercent'] as num).toDouble(),
      shippingCost: (json['shippingCost'] as num).toDouble(),
      vatRatePercent: (json['vatRatePercent'] as num).toDouble(),
      // Eski kayıtlarda (bu alan eklenmeden önce) bu alan hiç yoktu;
      // yoksa 0 varsayılır, geriye dönük uyumluluk bozulmaz.
      extraCost: json['extraCost'] != null ? (json['extraCost'] as num).toDouble() : 0,
      netProfit: (json['netProfit'] as num).toDouble(),
      roiPercent: (json['roiPercent'] as num).toDouble(),
    );
  }
}
