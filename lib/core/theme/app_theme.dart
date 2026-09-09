import 'package:flutter/material.dart';

/// Talkhimik palette: navy + gold (matches the team's document branding),
/// dark-first with a light option. High contrast per NFR-7.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF1B3A5B);
  static const gold = Color(0xFFB9892F);
  static const ink = Color(0xFF0E1621);
  static const surfaceDark = Color(0xFF17222E);

  /// Confidence badge colors (FR-4): readable on both themes.
  static const confidenceGreen = Color(0xFF2E9E44);
  static const confidenceAmber = Color(0xFFB26A00);
  static const confidenceRed = Color(0xFFC62828);
}

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.gold,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.gold,
        secondary: AppColors.navy,
        brightness: Brightness.dark,
        surface: AppColors.surfaceDark,
      ),
      scaffoldBackgroundColor: AppColors.ink,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
    );
