import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/calculators.dart';
import '../models/calculation_model.dart';
import '../models/marketplace_model.dart';

class CalculatorProvider extends ChangeNotifier {
  // --- E-Ticaret Tab State ---
  double buyPrice = 0;
  double sellPrice = 0;
  Marketplace marketplace = Marketplace.trendyol;
  double commissionRatePercent = Marketplace.trendyol.defaultCommissionRate;
  double shippingCost = 0;
  double vatRatePercent = 20;
  double buyVatRatePercent = 20;
  double extraCost = 0;

  EcommerceCalculationResult? ecommerceResult;

  /// Pro özelliği: PDF raporlarında uygulama adı yerine gösterilecek
  /// özel firma adı.
  String companyName = '';

  void setCompanyName(String name) {
    companyName = name;
    notifyListeners();
  }

  void setMarketplace(Marketplace m) {
    marketplace = m;
    commissionRatePercent = m.defaultCommissionRate;
    recalculateEcommerce();
  }

  void updateEcommerceInput({
    double? buyPrice,
    double? sellPrice,
    double? commissionRatePercent,
    double? shippingCost,
    double? vatRatePercent,
    double? buyVatRatePercent,
    double? extraCost,
  }) {
    if (buyPrice != null) this.buyPrice = buyPrice;
    if (sellPrice != null) this.sellPrice = sellPrice;
    if (commissionRatePercent != null) {
      this.commissionRatePercent = commissionRatePercent;
    }
    if (shippingCost != null) this.shippingCost = shippingCost;
    if (vatRatePercent != null) this.vatRatePercent = vatRatePercent;
    if (buyVatRatePercent != null) this.buyVatRatePercent = buyVatRatePercent;
    if (extraCost != null) this.extraCost = extraCost;
    recalculateEcommerce();
  }

  void recalculateEcommerce() {
    ecommerceResult = EcommerceCalculator.calculate(
      EcommerceCalculationInput(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        commissionRatePercent: commissionRatePercent,
        shippingCost: shippingCost,
        vatRatePercent: vatRatePercent,
        buyVatRatePercent: buyVatRatePercent,
        extraCost: extraCost,
      ),
    );
    notifyListeners();
  }

  double calculateDesiHelper({
    required double lengthCm,
    required double widthCm,
    required double heightCm,
  }) =>
      EcommerceCalculator.calculateDesi(
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
      );

  // --- Freelancer Tab State ---
  double freelancerGrossAmount = 0;
  double freelancerVatRate = 20;
  double freelancerWithholdingRate = 20;
  double freelancerStampDutyRate = 0;
  FreelancerCalculationResult? freelancerResult;

  void updateFreelancerGrossToNet({
    double? grossAmount,
    double? vatRate,
    double? withholdingRate,
    double? stampDutyRate,
  }) {
    if (grossAmount != null) freelancerGrossAmount = grossAmount;
    if (vatRate != null) freelancerVatRate = vatRate;
    if (withholdingRate != null) freelancerWithholdingRate = withholdingRate;
    if (stampDutyRate != null) freelancerStampDutyRate = stampDutyRate;

    freelancerResult = FreelancerCalculator.grossToNet(
      grossAmount: freelancerGrossAmount,
      vatRatePercent: freelancerVatRate,
      withholdingRatePercent: freelancerWithholdingRate,
      stampDutyRatePercent: freelancerStampDutyRate,
    );
    notifyListeners();
  }

  void updateFreelancerNetToGross({
    double? desiredNetAmount,
    double? vatRate,
    double? withholdingRate,
    double? stampDutyRate,
  }) {
    if (desiredNetAmount != null) freelancerGrossAmount = desiredNetAmount;
    if (vatRate != null) freelancerVatRate = vatRate;
    if (withholdingRate != null) freelancerWithholdingRate = withholdingRate;
    if (stampDutyRate != null) freelancerStampDutyRate = stampDutyRate;

    freelancerResult = FreelancerCalculator.netToGross(
      desiredNetAmount: freelancerGrossAmount,
      vatRatePercent: freelancerVatRate,
      withholdingRatePercent: freelancerWithholdingRate,
      stampDutyRatePercent: freelancerStampDutyRate,
    );
    notifyListeners();
  }

  double? minimumHourlyRate;

  void calculateMinimumHourlyRate({
    required double monthlyTargetIncome,
    required double weeklyWorkHours,
  }) {
    minimumHourlyRate = FreelancerCalculator.minimumHourlyRate(
      monthlyTargetIncome: monthlyTargetIncome,
      weeklyWorkHours: weeklyWorkHours,
    );
    notifyListeners();
  }

  // --- Kaydedilen Senaryolar (offline persistence) ---
  static const _savedCalculationsKey = 'saved_calculations';
  List<SavedCalculation> savedCalculations = [];

  Future<void> loadSavedCalculations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedCalculationsKey) ?? [];
    savedCalculations = raw
        .map((s) => SavedCalculation.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> saveCurrentEcommerceScenario(String title) async {
    if (ecommerceResult == null) return;
    final calc = SavedCalculation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      marketplace: marketplace,
      commissionRatePercent: commissionRatePercent,
      shippingCost: shippingCost,
      vatRatePercent: vatRatePercent,
      extraCost: extraCost,
      netProfit: ecommerceResult!.netProfit,
      roiPercent: ecommerceResult!.roiPercent,
    );
    savedCalculations.insert(0, calc);
    await _persistSavedCalculations();
    notifyListeners();
  }

  /// Kayıtlı bir senaryoyu seçildiğinde tüm E-Ticaret girdilerini
  /// (pazaryeri, fiyatlar, komisyon, kargo, KDV, ekstra gider) geri yükler
  /// ve hesaplamayı bir kerede yeniden yapar. UI katmanı (ecommerce_tab.dart)
  /// bu çağrıdan sonra kendi `TextEditingController`larını da senkronize eder.
  void loadSavedScenario(SavedCalculation calc) {
    marketplace = calc.marketplace;
    buyPrice = calc.buyPrice;
    sellPrice = calc.sellPrice;
    commissionRatePercent = calc.commissionRatePercent;
    shippingCost = calc.shippingCost;
    vatRatePercent = calc.vatRatePercent;
    buyVatRatePercent = calc.vatRatePercent; // ekranda ikisi hep aynı oranı kullanır
    extraCost = calc.extraCost;
    recalculateEcommerce();
  }

  Future<void> deleteSavedCalculation(String id) async {
    savedCalculations.removeWhere((c) => c.id == id);
    await _persistSavedCalculations();
    notifyListeners();
  }

  Future<void> _persistSavedCalculations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _savedCalculationsKey,
      savedCalculations.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }
}
