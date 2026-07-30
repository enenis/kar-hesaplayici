import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/calculator_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/result_card.dart';

class FreelancerTab extends StatefulWidget {
  const FreelancerTab({super.key});

  @override
  State<FreelancerTab> createState() => _FreelancerTabState();
}

enum _ConversionDirection { grossToNet, netToGross }

class _FreelancerTabState extends State<FreelancerTab> {
  final amountCtrl = TextEditingController();
  final monthlyTargetCtrl = TextEditingController();
  final weeklyHoursCtrl = TextEditingController();
  final vatRateCtrl = TextEditingController(text: '20');
  final withholdingRateCtrl = TextEditingController(text: '20');
  double vatRate = 20;
  double withholdingRate = 20;
  _ConversionDirection direction = _ConversionDirection.grossToNet;

  @override
  void dispose() {
    amountCtrl.dispose();
    monthlyTargetCtrl.dispose();
    weeklyHoursCtrl.dispose();
    vatRateCtrl.dispose();
    withholdingRateCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final provider = context.read<CalculatorProvider>();
    final amount = CurrencyFormatter.parseGrouped(amountCtrl.text);
    if (direction == _ConversionDirection.grossToNet) {
      provider.updateFreelancerGrossToNet(
        grossAmount: amount,
        vatRate: vatRate,
        withholdingRate: withholdingRate,
      );
    } else {
      provider.updateFreelancerNetToGross(
        desiredNetAmount: amount,
        vatRate: vatRate,
        withholdingRate: withholdingRate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalculatorProvider>();
    final result = provider.freelancerResult;
    final hPad = ResponsiveHelper.horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, ResponsiveHelper.bottomInset(context) + 100),
      child: ResponsiveLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Freelancer & Hizmet Makbuzu', style: AppTextStyles.h1(context)),
            const SizedBox(height: 4),
            Text('Brüt/Net dönüşüm, stopaj ve KDV dökümü', style: AppTextStyles.body(context)),
            const SizedBox(height: 20),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_ConversionDirection>(
                    segments: const [
                      ButtonSegment(
                        value: _ConversionDirection.grossToNet,
                        label: Text('Brüt → Net'),
                      ),
                      ButtonSegment(
                        value: _ConversionDirection.netToGross,
                        label: Text('Net → Brüt'),
                      ),
                    ],
                    selected: {direction},
                    onSelectionChanged: (s) {
                      setState(() => direction = s.first);
                      _recalculate();
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: direction == _ConversionDirection.grossToNet
                        ? 'Brüt Tutar'
                        : 'İstenen Net Tutar',
                    prefixText: '₺ ',
                    controller: amountCtrl,
                    useThousandsSeparator: true,
                    onChanged: (_) => _recalculate(),
                  ),
                  const SizedBox(height: 16),
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'KDV Oranı',
                        suffixText: '%',
                        hint: '20',
                        controller: vatRateCtrl,
                        onChanged: (v) {
                          vatRate = CurrencyFormatter.parseDecimal(v);
                          _recalculate();
                        },
                      ),
                      CustomTextField(
                        label: 'Stopaj Oranı',
                        suffixText: '%',
                        hint: '20',
                        controller: withholdingRateCtrl,
                        onChanged: (v) {
                          withholdingRate = CurrencyFormatter.parseDecimal(v);
                          _recalculate();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (result != null) ...[
              HeroResultCard(
                label: direction == _ConversionDirection.grossToNet ? 'Net Tutar' : 'Gereken Brüt Tutar',
                value: CurrencyFormatter.format(
                  direction == _ConversionDirection.grossToNet
                      ? result.netAmount
                      : result.grossAmount,
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Makbuz Dökümü', style: AppTextStyles.h2(context)),
                    const SizedBox(height: 16),
                    ResultMetric(
                      label: 'Brüt Tutar',
                      value: CurrencyFormatter.format(result.grossAmount),
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'KDV (+)',
                      value: CurrencyFormatter.format(result.vatAmount),
                      valueColor: AppColors.success,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Stopaj (-)',
                      value: CurrencyFormatter.format(result.withholdingAmount),
                      valueColor: AppColors.danger,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Damga Vergisi (-)',
                      value: CurrencyFormatter.format(result.stampDutyAmount),
                      valueColor: AppColors.danger,
                    ),
                    const Divider(height: 24),
                    ResultMetric(
                      label: 'Net Tahsilat',
                      value: CurrencyFormatter.format(result.netAmount),
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text('Saatlik Ücret Hesaplayıcı', style: AppTextStyles.h2(context)),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveRow(
                    children: [
                      CustomTextField(
                        label: 'Aylık Hedef Gelir',
                        prefixText: '₺ ',
                        controller: monthlyTargetCtrl,
                        useThousandsSeparator: true,
                        onChanged: (_) => _calcHourly(),
                      ),
                      CustomTextField(
                        label: 'Haftalık Çalışma Saati',
                        suffixText: 'saat',
                        controller: weeklyHoursCtrl,
                        onChanged: (_) => _calcHourly(),
                      ),
                    ],
                  ),
                  if (provider.minimumHourlyRate != null) ...[
                    const SizedBox(height: 16),
                    ResultMetric(
                      label: 'Minimum Saatlik Ücret',
                      value: CurrencyFormatter.format(provider.minimumHourlyRate!),
                      valueColor: AppColors.primary,
                      icon: Icons.access_time,
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

  void _calcHourly() {
    final provider = context.read<CalculatorProvider>();
    provider.calculateMinimumHourlyRate(
      monthlyTargetIncome: CurrencyFormatter.parseGrouped(monthlyTargetCtrl.text),
      weeklyWorkHours: CurrencyFormatter.parseDecimal(weeklyHoursCtrl.text),
    );
  }
}
