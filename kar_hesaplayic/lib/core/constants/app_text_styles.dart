import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Metin stilleri. Boyutlar sabit `double` değil; kullanım noktasında
/// `ResponsiveHelper.fontSize(context, base)` ile ölçeklenmesi beklenir.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 32),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color ?? _onSurface(context),
      );

  static TextStyle h1(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 24),
        fontWeight: FontWeight.w700,
        color: color ?? _onSurface(context),
      );

  static TextStyle h2(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 18),
        fontWeight: FontWeight.w600,
        color: color ?? _onSurface(context),
      );

  static TextStyle body(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 14),
        fontWeight: FontWeight.w400,
        color: color ?? _onSurfaceMuted(context),
      );

  static TextStyle bodyBold(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 14),
        fontWeight: FontWeight.w600,
        color: color ?? _onSurface(context),
      );

  static TextStyle caption(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 12),
        fontWeight: FontWeight.w400,
        color: color ?? _onSurfaceMuted(context),
      );

  static TextStyle metric(BuildContext context, {Color? color}) => TextStyle(
        fontSize: _scaled(context, 28),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color ?? AppColors.primary,
      );

  static double _scaled(BuildContext context, double base) {
    // MediaQuery textScaler ile sistem font tercihine saygı gösterir,
    // ama aşırı büyümeyi 1.3x ile sınırlar (layout taşmasını önlemek için).
    final scaler = MediaQuery.textScalerOf(context);
    final clamped = scaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
    return clamped.scale(base);
  }

  static Color _onSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight;

  static Color _onSurfaceMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight;
}
