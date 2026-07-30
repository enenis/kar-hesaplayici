import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/exchange_rate_service.dart';
import '../../core/utils/calculators.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_helper.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/result_card.dart';

class ExportTab extends StatefulWidget {
  const ExportTab({super.key});

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  final amountCtrl = TextEditingController();
  final rateCtrl = TextEditingController(text: '32.50'); // offline sabit varsayılan kur
  AppCurrency fromCurrency = AppCurrency.usd;
  double? convertedAmount;
  bool _isFetchingRate = false;
  ExchangeRateResult? _lastRateResult;

  final declaredValueCtrl = TextEditingController();
  final freightCtrl = TextEditingController();
  Map<String, double>? exportResult;

  void _convert() {
    setState(() {
      convertedAmount = ExportCalculator.convert(
        amount: CurrencyFormatter.parseGrouped(amountCtrl.text),
        // KRİTİK DÜZELTME: kur alanı ("47.3863" gibi) binlik ayraç
        // kullanmıyor; önceden parseGrouped ile nokta binlik ayraç sanılıp
        // "47.3863" -> 473863 gibi yanlış bir sonuca yol açıyordu.
        rate: CurrencyFormatter.parseDecimal(rateCtrl.text),
      );
    });
  }

  void _simulateExport() {
    setState(() {
      exportResult = ExportCalculator.simulateMicroExport(
        declaredValue: CurrencyFormatter.parseGrouped(declaredValueCtrl.text),
        freightCost: CurrencyFormatter.parseGrouped(freightCtrl.text),
      );
    });
  }

  Future<void> _fetchLiveRate() async {
    if (_isFetchingRate) return;
    setState(() => _isFetchingRate = true);

    final result = await ExchangeRateService.instance.fetchRateToTry(fromCurrency.code);

    if (!mounted) return;
    setState(() {
      _isFetchingRate = false;
      _lastRateResult = result;
      rateCtrl.text = result.rate.toStringAsFixed(4);
    });
    _convert();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isLive
              ? 'Güncel kur çekildi: 1 ${fromCurrency.code} = ${result.rate.toStringAsFixed(4)} ₺'
              : 'İnternet yok / servis yanıt vermedi — önbellek/varsayılan kur kullanılıyor.',
        ),
        backgroundColor: result.isLive ? AppColors.success : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = ResponsiveHelper.horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, ResponsiveHelper.bottomInset(context) + 100),
      child: ResponsiveLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Döviz & Mikro İhracat', style: AppTextStyles.h1(context)),
            const SizedBox(height: 4),
            Text('Kur dönüşümü ve ETGB muafiyet simülasyonu', style: AppTextStyles.body(context)),
            const SizedBox(height: 20),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Döviz Dönüştürücü', style: AppTextStyles.h2(context)),
                  const SizedBox(height: 16),
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'Tutar',
                        prefixText: fromCurrency.symbol,
                        controller: amountCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _convert(),
                      ),
                      CustomTextField(
                        label: 'Kur (₺ karşılığı)',
                        controller: rateCtrl,
                        onChanged: (_) => _convert(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: AppCurrency.values.map((c) {
                      final selected = fromCurrency == c;
                      return ChoiceChip(
                        label: Text(c.code),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => fromCurrency = c);
                          _convert();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isFetchingRate ? null : _fetchLiveRate,
                    icon: _isFetchingRate
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(_isFetchingRate ? 'Kur çekiliyor...' : 'Güncel Kuru Çek'),
                  ),
                  if (_lastRateResult != null)
                    Text(
                      _lastRateResult!.isLive
                          ? 'Kaynak: canlı API (open.er-api.com)'
                          : _lastRateResult!.fetchedAt != null
                              ? 'Kaynak: önbellek (${_lastRateResult!.fetchedAt!.day}.${_lastRateResult!.fetchedAt!.month}.${_lastRateResult!.fetchedAt!.year} itibarıyla)'
                              : 'Kaynak: offline varsayılan kur',
                      style: AppTextStyles.caption(context),
                    ),
                  if (convertedAmount != null) ...[
                    const SizedBox(height: 8),
                    ResultMetric(
                      label: 'Karşılığı',
                      // NumberFormat.currency ile ondalık ayırıcı (virgül) ve
                      // binlik ayırıcı (nokta) tr_TR kurallarına göre doğru
                      // biçimlendirilir — örn. 473.86 -> "473,86 TL".
                      value: NumberFormat.currency(
                        locale: 'tr_TR',
                        symbol: 'TL',
                        decimalDigits: 2,
                      ).format(convertedAmount!),
                      valueColor: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mikro İhracat (ETGB) Simülasyonu', style: AppTextStyles.h2(context)),
                  const SizedBox(height: 4),
                  Text(
                    '15.000 EUR altı gönderiler için basitleştirilmiş muafiyet tahmini',
                    style: AppTextStyles.caption(context),
                  ),
                  const SizedBox(height: 16),
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'Beyan Değeri',
                        prefixText: '€ ',
                        controller: declaredValueCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _simulateExport(),
                      ),
                      CustomTextField(
                        label: 'Navlun Ücreti',
                        prefixText: '₺ ',
                        controller: freightCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _simulateExport(),
                      ),
                    ],
                  ),
                  if (exportResult != null) ...[
                    const SizedBox(height: 16),
                    ResultMetric(
                      label: 'Gümrük Muafiyeti',
                      value: exportResult!['isExempt'] == 1.0 ? 'Muaf ✅' : 'Muaf Değil',
                      valueColor: exportResult!['isExempt'] == 1.0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Gümrük Vergisi',
                      value: CurrencyFormatter.format(exportResult!['customsDuty']!),
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Toplam Gönderim Maliyeti',
                      value: CurrencyFormatter.format(exportResult!['totalCost']!),
                      valueColor: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
