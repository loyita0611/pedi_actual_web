// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// Paleta unica de PediActual. Antes cada pantalla repetia sus propios
/// Color(0xFF...) y mezclaba Colors.teal con el color de marca.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4594A4);
  static const Color primaryDark = Color(0xFF2F6E7B);
  static const Color primarySoft = Color(0xFFE7F1F3);

  static const Color accent = Color(0xFFEAA171);
  static const Color accentDark = Color(0xFFC97C48);

  static const Color background = Color(0xFFF4F7F6);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE1E8E7);

  static const Color textPrimary = Color(0xFF17262A);
  static const Color textSecondary = Color(0xFF5B6B6E);
  static const Color textMuted = Color(0xFF90A0A2);

  static const Color success = Color(0xFF2E7D5B);
  static const Color successSoft = Color(0xFFE3F3EC);
  static const Color warning = Color(0xFFB07A1E);
  static const Color warningSoft = Color(0xFFFBF1DC);
  static const Color danger = Color(0xFFB3382E);
  static const Color dangerSoft = Color(0xFFFAE7E5);
  static const Color info = Color(0xFF2C6EA8);
  static const Color infoSoft = Color(0xFFE4EEF7);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        prefixIconColor: AppColors.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
