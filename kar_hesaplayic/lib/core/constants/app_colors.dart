import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renk paleti.
/// Neumorphic / Soft Glassmorphism esintili, finans güveni veren tonlar.
class AppColors {
  AppColors._();

  // Light mode
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Dark mode
  static const Color backgroundDark = Color(0xFF0F172A); // Kömür grisi
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Accent (her iki temada sabit kalır)
  static const Color primary = Color(0xFF0D9488); // Deep Emerald / Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF6366F1); // Muted Indigo

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Grafik renkleri (Maliyet / Komisyon / Kâr dağılımı)
  static const Color chartCost = Color(0xFF94A3B8);
  static const Color chartCommission = Color(0xFF6366F1);
  static const Color chartProfit = Color(0xFF0D9488);

  static LinearGradient primaryGradient = const LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
