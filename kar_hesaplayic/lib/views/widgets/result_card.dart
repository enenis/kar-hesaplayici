import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ResultMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const ResultMetric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textSecondaryLight),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.body(context)),
          ],
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyBold(context, color: valueColor),
          ),
        ),
      ],
    );
  }
}

/// Büyük, öne çıkan ana sonuç kartı (Net Kâr gibi).
/// Kâr/zarar durumuna göre renk paleti ve yumuşak "glow" efekti arasında
/// animasyonlu geçiş yapar; değer değiştiğinde hafif bir nabız/scale efekti verir.
class HeroResultCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subValue;
  final bool isPositive;

  const HeroResultCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.isPositive = true,
  });

  @override
  State<HeroResultCard> createState() => _HeroResultCardState();
}

class _HeroResultCardState extends State<HeroResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant HeroResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.isPositive != widget.isPositive) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.isPositive ? AppColors.success : AppColors.danger;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        // 0 -> 1 -> 0.6 arası yumuşak bir "nefes alma" glow yoğunluğu.
        final t = _pulseController.value;
        final glowStrength = t < 0.5 ? t * 2 : 1 - (t - 0.5) * 0.8;
        final scale = 1 + (t < 0.5 ? t * 0.02 : (1 - t) * 0.02);

        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35 * glowStrength),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                widget.isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTextStyles.body(context, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.value,
              style: AppTextStyles.display(context, color: Colors.white),
            ),
          ),
          if (widget.subValue != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.subValue!,
                style: AppTextStyles.caption(context, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minimalist dairesel ROI (Kâr Oranı) göstergesi.
/// [roiPercent] negatif de olabilir; -100..+100 aralığına clamp edilerek
/// halka doluluk oranına çevrilir. Renk pozitif/negatife göre değişir.
class RoiGauge extends StatelessWidget {
  final double roiPercent;
  final double size;

  const RoiGauge({super.key, required this.roiPercent, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final isPositive = roiPercent >= 0;
    final color = isPositive ? AppColors.primary : AppColors.danger;
    final clamped = roiPercent.abs().clamp(0, 100) / 100.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RoiGaugePainter(progress: value, color: color),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isPositive ? '+' : ''}${roiPercent.toStringAsFixed(0)}%',
                style: AppTextStyles.bodyBold(context, color: color),
              ),
              Text('ROI', style: AppTextStyles.caption(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoiGaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _RoiGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoiGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Doğrusal, ince "Kâr Oranı" ilerleme çubuğu (RoiGauge'a alternatif,
/// dar/liste görünümlerinde kullanılabilir).
class RoiProgressBar extends StatelessWidget {
  final double roiPercent;

  const RoiProgressBar({super.key, required this.roiPercent});

  @override
  Widget build(BuildContext context) {
    final isPositive = roiPercent >= 0;
    final color = isPositive ? AppColors.primary : AppColors.danger;
    final clamped = (roiPercent.abs().clamp(0, 100)) / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Kâr Oranı (ROI)', style: AppTextStyles.body(context)),
            Text(
              '${isPositive ? '+' : ''}${roiPercent.toStringAsFixed(1)}%',
              style: AppTextStyles.bodyBold(context, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}
