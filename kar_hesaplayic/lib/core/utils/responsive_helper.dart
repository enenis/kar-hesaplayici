import 'package:flutter/material.dart';

/// Sabit piksel değerleri yerine ekran boyutuna göre ölçekleme sağlayan
/// yardımcı sınıf. Küçük telefon (SE) -> tablet/foldable arası her
/// genişlikte tutarlı bir görünüm sağlar.
class ResponsiveHelper {
  ResponsiveHelper._();

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < desktopBreakpoint;
  }

  static bool isDesktopLike(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// İçerik genişliğini büyük ekranlarda sınırlar (aşırı gerilmeyi önler).
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktopBreakpoint) return 720;
    if (w >= mobileBreakpoint) return w * 0.85;
    return w;
  }

  /// Kart / bölüm arası yatay padding, ekran genişliğine göre orantılı.
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 12;
    if (w < mobileBreakpoint) return 20;
    return 32;
  }

  /// Grid / yan yana kart düzeni için sütun sayısı.
  static int gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= desktopBreakpoint) return 3;
    if (w >= mobileBreakpoint) return 2;
    return 1;
  }

  /// Klavye açıkken alt boşluğu hesaplar (safe-area + viewInsets).
  static double bottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.viewInsets.bottom + mq.padding.bottom;
  }
}
