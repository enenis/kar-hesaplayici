import 'dart:math';

/// ----------------------------------------------------------------------
/// E-TİCARET PAZARYERİ KÂR HESAPLAMA
/// ----------------------------------------------------------------------
class EcommerceCalculationInput {
  final double buyPrice; // Alış fiyatı (KDV dahil varsayılır)
  final double sellPrice; // Hedef satış fiyatı (KDV dahil)
  final double commissionRatePercent; // Pazaryeri komisyon oranı
  final double shippingCost; // Sabit kargo ücreti (desi ile hesaplandıysa buraya yazılır)
  final double vatRatePercent; // Satış KDV oranı
  final double buyVatRatePercent; // Alış KDV oranı (indirim konusu edilebilir KDV)
  final double extraCost; // Pazarlama / paketleme ek gideri

  const EcommerceCalculationInput({
    required this.buyPrice,
    required this.sellPrice,
    required this.commissionRatePercent,
    required this.shippingCost,
    required this.vatRatePercent,
    this.buyVatRatePercent = 0,
    this.extraCost = 0,
  });
}

class EcommerceCalculationResult {
  final double commissionAmount;
  final double netVatBurden; // Satış KDV - Alış KDV (ödenecek net KDV)
  final double totalCosts; // Alış + Komisyon + Kargo + Ekstra + Net KDV
  final double netProfit;
  final double roiPercent; // Net kâr / Alış fiyatı
  final double breakEvenPrice; // Sıfır kâr için gereken min. satış fiyatı
  final double profitMarginPercent; // Net kâr / Satış fiyatı

  const EcommerceCalculationResult({
    required this.commissionAmount,
    required this.netVatBurden,
    required this.totalCosts,
    required this.netProfit,
    required this.roiPercent,
    required this.breakEvenPrice,
    required this.profitMarginPercent,
  });
}

class EcommerceCalculator {
  static EcommerceCalculationResult calculate(EcommerceCalculationInput input) {
    final commissionAmount = input.sellPrice * (input.commissionRatePercent / 100);

    // KDV matrahını basitleştirilmiş şekilde satış/alış fiyatının içinden ayıklıyoruz.
    final sellVatAmount = input.sellPrice -
        (input.sellPrice / (1 + input.vatRatePercent / 100));
    final buyVatAmount = input.buyVatRatePercent > 0
        ? input.buyPrice - (input.buyPrice / (1 + input.buyVatRatePercent / 100))
        : 0.0;
    final netVatBurden = max(0, sellVatAmount - buyVatAmount).toDouble();

    final totalCosts = input.buyPrice +
        commissionAmount +
        input.shippingCost +
        input.extraCost +
        netVatBurden;

    final netProfit = input.sellPrice - totalCosts;
    final roiPercent = input.buyPrice > 0 ? (netProfit / input.buyPrice) * 100 : 0;
    final profitMarginPercent =
        input.sellPrice > 0 ? (netProfit / input.sellPrice) * 100 : 0;

    // Break-even: sellPrice - commission(sellPrice) - shipping - extra - buyPrice - vat(sellPrice) = 0
    // Basitleştirilmiş yaklaşım: sabit maliyetleri sabit kabul edip komisyon/KDV oranı üzerinden çözülür.
    final variableRate =
        (input.commissionRatePercent / 100) + (input.vatRatePercent / (100 + input.vatRatePercent));
    final fixedCosts = input.buyPrice + input.shippingCost + input.extraCost - buyVatAmount;
    final breakEvenPrice =
        variableRate < 1 ? fixedCosts / (1 - variableRate) : double.infinity;

    return EcommerceCalculationResult(
      commissionAmount: commissionAmount,
      netVatBurden: netVatBurden,
      totalCosts: totalCosts,
      netProfit: netProfit,
      roiPercent: roiPercent.toDouble(),
      breakEvenPrice: breakEvenPrice,
      profitMarginPercent: profitMarginPercent.toDouble(),
    );
  }

  /// En x Boy x Yükseklik (cm) / 3000 -> Desi
  static double calculateDesi({
    required double lengthCm,
    required double widthCm,
    required double heightCm,
    double divisor = 3000,
  }) {
    final volumetric = (lengthCm * widthCm * heightCm) / divisor;
    return double.parse(volumetric.toStringAsFixed(2));
  }
}

/// ----------------------------------------------------------------------
/// FREELANCER / HİZMET MAKBUZU HESAPLAMA
/// ----------------------------------------------------------------------
class FreelancerCalculationResult {
  final double grossAmount;
  final double vatAmount;
  final double withholdingAmount; // Stopaj
  final double stampDutyAmount; // Damga vergisi
  final double netAmount;

  const FreelancerCalculationResult({
    required this.grossAmount,
    required this.vatAmount,
    required this.withholdingAmount,
    required this.stampDutyAmount,
    required this.netAmount,
  });
}

class FreelancerCalculator {
  /// Brüt tutardan net tutarı hesaplar (serbest meslek makbuzu mantığı).
  /// vatRate: KDV oranı (genelde %20), withholdingRate: stopaj (genelde %20),
  /// stampDutyRate: damga vergisi oranı (binde ~9.48, opsiyonel).
  static FreelancerCalculationResult grossToNet({
    required double grossAmount,
    double vatRatePercent = 20,
    double withholdingRatePercent = 20,
    double stampDutyRatePercent = 0,
  }) {
    final vatAmount = grossAmount * (vatRatePercent / 100);
    final withholdingAmount = grossAmount * (withholdingRatePercent / 100);
    final stampDutyAmount = grossAmount * (stampDutyRatePercent / 100);
    final netAmount = grossAmount + vatAmount - withholdingAmount - stampDutyAmount;

    return FreelancerCalculationResult(
      grossAmount: grossAmount,
      vatAmount: vatAmount,
      withholdingAmount: withholdingAmount,
      stampDutyAmount: stampDutyAmount,
      netAmount: netAmount,
    );
  }

  /// İstenen net tutara ulaşmak için gereken brüt tutarı geriye doğru çözer.
  static FreelancerCalculationResult netToGross({
    required double desiredNetAmount,
    double vatRatePercent = 20,
    double withholdingRatePercent = 20,
    double stampDutyRatePercent = 0,
  }) {
    // net = gross * (1 + vat% - withholding% - stampDuty%)
    final factor = 1 +
        (vatRatePercent / 100) -
        (withholdingRatePercent / 100) -
        (stampDutyRatePercent / 100);
    final grossAmount = factor > 0 ? desiredNetAmount / factor : desiredNetAmount;
    return grossToNet(
      grossAmount: grossAmount,
      vatRatePercent: vatRatePercent,
      withholdingRatePercent: withholdingRatePercent,
      stampDutyRatePercent: stampDutyRatePercent,
    );
  }

  /// Aylık hedef gelir ve haftalık çalışma saatine göre minimum saatlik ücret.
  static double minimumHourlyRate({
    required double monthlyTargetIncome,
    required double weeklyWorkHours,
    double weeksPerMonth = 4.33,
  }) {
    final monthlyHours = weeklyWorkHours * weeksPerMonth;
    if (monthlyHours <= 0) return 0;
    return monthlyTargetIncome / monthlyHours;
  }
}

/// ----------------------------------------------------------------------
/// DÖVİZ & MİKRO İHRACAT
/// ----------------------------------------------------------------------
class ExportCalculator {
  /// Basit döviz dönüşümü.
  static double convert({
    required double amount,
    required double rate,
  }) =>
      amount * rate;

  /// ETGB / Mikro ihracat basit navlun + gümrük muafiyet simülasyonu.
  /// [declaredValue] gümrük beyan değeri, [freightCost] navlun,
  /// [exemptionThreshold] muafiyet sınırı (örn. 15.000 EUR mikro ihracat).
  static Map<String, double> simulateMicroExport({
    required double declaredValue,
    required double freightCost,
    double exemptionThreshold = 15000,
    double customsDutyRatePercent = 0,
  }) {
    final isExempt = declaredValue <= exemptionThreshold;
    final customsDuty =
        isExempt ? 0.0 : declaredValue * (customsDutyRatePercent / 100);
    final totalCost = freightCost + customsDuty;

    return {
      'customsDuty': customsDuty,
      'freightCost': freightCost,
      'totalCost': totalCost,
      'isExempt': isExempt ? 1.0 : 0.0,
    };
  }
}
