import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/calculation_model.dart';
import '../../models/marketplace_model.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/premium_provider.dart';
import '../../core/services/admob_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/result_card.dart';

class EcommerceTab extends StatefulWidget {
  const EcommerceTab({super.key});

  @override
  State<EcommerceTab> createState() => _EcommerceTabState();
}

class _EcommerceTabState extends State<EcommerceTab> {
  final buyCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final commissionCtrl = TextEditingController();
  final shippingCtrl = TextEditingController();
  final extraCtrl = TextEditingController();
  double vatRate = 20;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CalculatorProvider>();
    commissionCtrl.text = provider.commissionRatePercent.toStringAsFixed(1);
  }

  @override
  void dispose() {
    buyCtrl.dispose();
    sellCtrl.dispose();
    commissionCtrl.dispose();
    shippingCtrl.dispose();
    extraCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final provider = context.read<CalculatorProvider>();
    provider.updateEcommerceInput(
      buyPrice: CurrencyFormatter.parseGrouped(buyCtrl.text),
      sellPrice: CurrencyFormatter.parseGrouped(sellCtrl.text),
      // Komisyon oranı alanı binlik ayraç KULLANMIYOR ("18.0" gibi serbest
      // ondalık girişler kabul ediyor) — bu yüzden parseDecimal kullanılmalı.
      // Önceden parseGrouped kullanılıyordu ve "18.0" -> 180 gibi yanlış
      // sonuçlar üretiyordu.
      commissionRatePercent: CurrencyFormatter.parseDecimal(commissionCtrl.text),
      shippingCost: CurrencyFormatter.parseGrouped(shippingCtrl.text),
      vatRatePercent: vatRate,
      buyVatRatePercent: vatRate,
      extraCost: CurrencyFormatter.parseGrouped(extraCtrl.text),
    );
  }

  Future<void> _openDesiDialog() async {
    final lengthCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardTheme.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Desi Hesapla', style: AppTextStyles.h1(ctx)),
                  const SizedBox(height: 4),
                  Text('En x Boy x Yükseklik (cm) / 3000', style: AppTextStyles.caption(ctx)),
                  const SizedBox(height: 20),
                  CustomTextField(label: 'En (cm)', controller: lengthCtrl),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Boy (cm)', controller: widthCtrl),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Yükseklik (cm)', controller: heightCtrl),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final provider = context.read<CalculatorProvider>();
                        final desi = provider.calculateDesiHelper(
                          lengthCm: CurrencyFormatter.parseDecimal(lengthCtrl.text),
                          widthCm: CurrencyFormatter.parseDecimal(widthCtrl.text),
                          heightCm: CurrencyFormatter.parseDecimal(heightCtrl.text),
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hesaplanan Desi: ${desi.toStringAsFixed(2)}'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: const Text('Hesapla'),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveScenario() async {
    final premium = context.read<PremiumProvider>();
    final provider = context.read<CalculatorProvider>();
    if (!premium.isPro && provider.savedCalculations.length >= 3) {
      _showProPaywallSnackbar();
      return;
    }

    final titleCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Senaryoyu Kaydet'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'Örn: Kış Ceket Kampanyası'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );

    if (confirmed == true && titleCtrl.text.trim().isNotEmpty) {
      await provider.saveCurrentEcommerceScenario(titleCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senaryo kaydedildi.')),
        );
      }
    }
  }

  bool _isExporting = false;
  bool _loadingDialogShown = false;

  /// Ekranın tam ortasında, taşma riski olmayan bir modal gösterge:
  /// "Reklam Yükleniyor / PDF Hazırlanıyor..." Kullanıcı bu sırada geri
  /// tuşuyla ya da ekrana dokunarak diyaloğu kapatamaz (barrierDismissible: false).
  void _showLoadingDialog() {
    if (_loadingDialogShown || !mounted) return;
    _loadingDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      'Reklam Yükleniyor /\nPDF Hazırlanıyor...',
                      style: AppTextStyles.bodyBold(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (!_loadingDialogShown) return;
    _loadingDialogShown = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// PDF akışı — KESİN KURAL: PDF oluşturma işlemi SADECE kullanıcı
  /// reklamı sonuna kadar izleyip ödülü hak ettiğinde (ve reklam TAMAMEN
  /// kapandıktan sonra — bkz. admob_service.dart) tetiklenir. Reklamı ödül
  /// kazanmadan kapatırsa PDF OLUŞMAZ (kullanıcıya bilgi verilir).
  ///
  /// İSTİSNA (fail-open): Reklam hiç yüklenemediyse veya gösterilirken hata
  /// verdiyse, kullanıcı mağdur edilmez — PDF doğrudan oluşturulur.
  ///
  /// Pro kullanıcılar ve web'de reklam adımı (onay diyaloğu dahil) tamamen atlanır.
  Future<void> _exportPdf() async {
    final provider = context.read<CalculatorProvider>();
    final premium = context.read<PremiumProvider>();
    final result = provider.ecommerceResult;
    if (result == null || _isExporting) return;

    final showAdStep = !premium.isPro && !kIsWeb;

    // Reklam gösterilmeden önce kullanıcıyı bilgilendiren onay diyaloğu.
    if (showAdStep) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ücretsiz PDF İndirme'),
          content: const Text(
            'Kısa bir reklam izleyerek PDF\'inizi ücretsiz indirebilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reklamı İzle'),
            ),
          ],
        ),
      );
      if (confirmed != true) return; // Kullanıcı vazgeçti, hiçbir şey tetiklenmez.
    }

    if (!mounted || _isExporting) return;
    setState(() => _isExporting = true);
    _showLoadingDialog();

    Future<void> generate() async {
      try {
        await PdfReportService.instance.generateAndShareEcommerceReport(
          marketplace: provider.marketplace,
          buyPrice: provider.buyPrice,
          sellPrice: provider.sellPrice,
          commissionRatePercent: provider.commissionRatePercent,
          shippingCost: provider.shippingCost,
          vatRatePercent: provider.vatRatePercent,
          result: result,
          // Pro kullanıcılar özel firma adı ekleyebilir; ücretsizde varsayılan başlık kullanılır.
          companyName: premium.isPro ? provider.companyName : null,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rapor oluşturulurken bir sorun oluştu.')),
          );
        }
      }
    }

    try {
      if (showAdStep) {
        await AdMobService.instance.showRewardedAd(
          // Ödül kazanıldı (VE reklam tamamen kapandı) -> PDF oluştur.
          onUserEarnedReward: generate,
          // Reklam hazır değil / 5 sn içinde yüklenmedi / gösterilirken hata
          // verdi -> kullanıcıyı mağdur etme, PDF'i yine de doğrudan oluştur.
          onFailedOrUnavailable: generate,
          // Reklam sorunsuz gösterildi ama ödül kazanılmadan kapatıldı ->
          // PDF OLUŞTURULMAZ, kullanıcı bilgilendirilir.
          onDismissedWithoutReward: () async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'PDF oluşturmak için reklamı sonuna kadar izlemeniz gerekiyor.',
                  ),
                ),
              );
            }
          },
        );
      } else {
        await generate();
      }
    } finally {
      // Ne olursa olsun (başarı, hata, reklam SDK istisnası, ödül
      // kazanılmadan kapatma) diyalog kapanır ve buton kesinlikle tekrar
      // tıklanabilir hale gelir.
      _hideLoadingDialog();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showProPaywallSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ücretsiz sürümde en fazla 3 senaryo kaydedebilirsiniz. Pro\'ya geçin!'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalculatorProvider>();
    final result = provider.ecommerceResult;
    final hPad = ResponsiveHelper.horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        hPad,
        20,
        hPad,
        ResponsiveHelper.bottomInset(context) + 100, // banner reklama yer aç
      ),
      child: ResponsiveLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('E-Ticaret Kâr Hesaplayıcı', style: AppTextStyles.h1(context)),
            const SizedBox(height: 4),
            Text(
              'Pazaryeri komisyonu, kargo ve KDV dahil net kârınızı görün',
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 20),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pazaryeri', style: AppTextStyles.bodyBold(context)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Marketplace.values.map((m) {
                      final selected = provider.marketplace == m;
                      return ChoiceChip(
                        label: Text(m.label),
                        selected: selected,
                        onSelected: (_) {
                          provider.setMarketplace(m);
                          commissionCtrl.text =
                              provider.commissionRatePercent.toStringAsFixed(1);
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.primary : null,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'Ürün Alış Fiyatı',
                        prefixText: '₺ ',
                        controller: buyCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _recalculate(),
                      ),
                      CustomTextField(
                        label: 'Hedef Satış Fiyatı',
                        prefixText: '₺ ',
                        controller: sellCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _recalculate(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'Komisyon Oranı',
                        suffixText: '%',
                        controller: commissionCtrl,
                        onChanged: (_) => _recalculate(),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextField(
                            label: 'Kargo Ücreti',
                            prefixText: '₺ ',
                            controller: shippingCtrl,
                            useThousandsSeparator: true,
                            onChanged: (_) => _recalculate(),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _openDesiDialog,
                            icon: const Icon(Icons.straighten, size: 16),
                            label: const Text('Desiden Hesapla'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('KDV Oranı', style: AppTextStyles.bodyBold(context)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [1, 10, 20].map((r) {
                      final selected = vatRate == r;
                      return ChoiceChip(
                        label: Text('%$r'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => vatRate = r.toDouble());
                          _recalculate();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Pazarlama / Paketleme Bütçesi (Opsiyonel)',
                    prefixText: '₺ ',
                    controller: extraCtrl,
                    useThousandsSeparator: true,
                    onChanged: (_) => _recalculate(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (result != null) ...[
              HeroResultCard(
                label: 'Net Kâr',
                value: CurrencyFormatter.format(result.netProfit),
                subValue: 'ROI: ${CurrencyFormatter.percent(result.roiPercent)}',
                isPositive: result.netProfit >= 0,
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    RoiGauge(roiPercent: result.roiPercent),
                    const SizedBox(width: 20),
                    Expanded(
                      child: RoiProgressBar(roiPercent: result.roiPercent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Gelir Dağılımı', style: AppTextStyles.h2(context)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _DistributionChart(
                        cost: provider.buyPrice,
                        commission: result.commissionAmount,
                        profit: result.netProfit < 0 ? 0 : result.netProfit,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Detaylı Döküm', style: AppTextStyles.h2(context)),
                    const SizedBox(height: 16),
                    ResultMetric(
                      label: 'Pazaryeri Kesintisi',
                      value: CurrencyFormatter.format(result.commissionAmount),
                      icon: Icons.storefront_outlined,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Net KDV Yükü',
                      value: CurrencyFormatter.format(result.netVatBurden),
                      icon: Icons.receipt_long_outlined,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Toplam Maliyet',
                      value: CurrencyFormatter.format(result.totalCosts),
                      icon: Icons.payments_outlined,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Kâr Marjı',
                      value: CurrencyFormatter.percent(result.profitMarginPercent),
                      icon: Icons.percent,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Başabaş Satış Fiyatı',
                      value: result.breakEvenPrice.isFinite
                          ? CurrencyFormatter.format(result.breakEvenPrice)
                          : '—',
                      icon: Icons.balance_outlined,
                      valueColor: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ResponsiveRow(
                children: [
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _saveScenario,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Senaryoyu Kaydet'),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _exportPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_isExporting ? 'Hazırlanıyor...' : 'Raporu İndir / Paylaş'),
                    ),
                  ),
                ],
              ),
            ] else
              GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Hesaplamayı görmek için alış ve satış fiyatını girin.',
                      style: AppTextStyles.body(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // --- Kayıtlı Senaryolar ---
            // Mevcut hesaplama sonucu olsun olmasın her zaman gösterilir;
            // kullanıcı buradan eski bir senaryoyu seçip yukarıdaki tüm
            // alanları (pazaryeri, fiyatlar, komisyon, kargo, KDV, ekstra
            // gider) tek dokunuşla geri yükleyebilir.
            if (provider.savedCalculations.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Kayıtlı Senaryolar', style: AppTextStyles.h2(context)),
              const SizedBox(height: 4),
              Text(
                'Birine dokunarak tüm alanları otomatik doldurun',
                style: AppTextStyles.caption(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 122,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.savedCalculations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final calc = provider.savedCalculations[index];
                    return _SavedScenarioCard(
                      calculation: calc,
                      onTap: () => _loadScenario(calc),
                      onDelete: () => _confirmDeleteScenario(calc),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kayıtlı bir senaryoyu seçtiğinde: provider'daki tüm E-Ticaret girdilerini
  /// geri yükler VE bu ekrandaki `TextEditingController`ları (görünen metin
  /// alanlarını) senkronize eder — provider state'i güncellemek tek başına
  /// ekrandaki yazıyı değiştirmez, controller'ların da elle güncellenmesi gerekir.
  void _loadScenario(SavedCalculation calc) {
    final provider = context.read<CalculatorProvider>();
    provider.loadSavedScenario(calc);

    buyCtrl.text = CurrencyFormatter.formatForGroupedField(calc.buyPrice);
    sellCtrl.text = CurrencyFormatter.formatForGroupedField(calc.sellPrice);
    commissionCtrl.text = calc.commissionRatePercent.toStringAsFixed(1);
    shippingCtrl.text = CurrencyFormatter.formatForGroupedField(calc.shippingCost);
    extraCtrl.text = CurrencyFormatter.formatForGroupedField(calc.extraCost);
    setState(() => vatRate = calc.vatRatePercent);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${calc.title}" yüklendi.')),
    );
  }

  Future<void> _confirmDeleteScenario(SavedCalculation calc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Senaryoyu Sil'),
        content: Text('"${calc.title}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<CalculatorProvider>().deleteSavedCalculation(calc.id);
    }
  }
}

/// Kayıtlı bir senaryoyu temsil eden kart — adı, kaydedildiği tarih ve net
/// kâr özetini gösterir; dokunulduğunda ilgili senaryo geri yüklenir.
class _SavedScenarioCard extends StatelessWidget {
  final SavedCalculation calculation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedScenarioCard({
    required this.calculation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(calculation.createdAt);
    final isProfit = calculation.netProfit >= 0;

    return SizedBox(
      width: 190,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    calculation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold(context),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(dateStr, style: AppTextStyles.caption(context)),
            const Spacer(),
            Text(
              CurrencyFormatter.format(calculation.netProfit),
              style: AppTextStyles.bodyBold(
                context,
                color: isProfit ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionChart extends StatelessWidget {
  final double cost;
  final double commission;
  final double profit;

  const _DistributionChart({
    required this.cost,
    required this.commission,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    final total = cost + commission + profit;
    if (total <= 0) {
      return Center(child: Text('Veri yok', style: AppTextStyles.caption(context)));
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 36,
              sections: [
                PieChartSectionData(
                  value: cost,
                  color: AppColors.chartCost,
                  title: '',
                  radius: 26,
                ),
                PieChartSectionData(
                  value: commission,
                  color: AppColors.chartCommission,
                  title: '',
                  radius: 26,
                ),
                PieChartSectionData(
                  value: profit,
                  color: AppColors.chartProfit,
                  title: '',
                  radius: 26,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendRow(color: AppColors.chartCost, label: 'Maliyet', value: cost),
              const SizedBox(height: 10),
              _LegendRow(color: AppColors.chartCommission, label: 'Komisyon', value: commission),
              const SizedBox(height: 10),
              _LegendRow(color: AppColors.chartProfit, label: 'Kâr', value: profit),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTextStyles.caption(context))),
        Text(CurrencyFormatter.format(value), style: AppTextStyles.caption(context)),
      ],
    );
  }
}
