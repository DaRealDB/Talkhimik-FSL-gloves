import 'package:flutter/material.dart';

/// Talkhimik design tokens (approved 2026-10, "simplify + refresh" pass) —
/// Pokémon GO Hub-style: brand green surfaces, olive-lime header bands with
/// a deep-green diagonal corner, warm-gray page, light rounded cards, pill
/// shapes. LIGHT is the primary theme; the dark variant derives from the
/// same hues. WCAG AA throughout (on-lime text is near-black — white fails).
class AppColors {
  AppColors._();

  // Brand (light)
  static const brandGreen = Color(0xFF067A4C); // app bar, primary buttons
  static const forest = Color(0xFF17713F); // diagonal corner, outlines
  static const lime = Color(0xFF7CA526); // header band
  static const limeText = Color(0xFF1C280A); // on-lime (AA)
  static const primaryContainer = Color(0xFFCFE8D8);
  static const onPrimaryContainer = Color(0xFF0A3323);
  static const warmPage = Color(0xFFD6D4CD);
  static const card = Color(0xFFEAE8E2);
  static const surfaceVariant = Color(0xFFBFBDB6);
  static const outlineGray = Color(0xFF8F8D87);
  static const text = Color(0xFF1D1C19);
  static const textMuted = Color(0xFF4A4944);

  // State
  static const success = Color(0xFF1B7A3D);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFB3261E);

  // Finger fill gradient (neutral → lime as flexion grows).
  static const fingerLow = Color(0xFFD8D0C4);
  static const fingerHigh = Color(0xFF7CA526);

  /// Confidence badge colors (FR-4): outline-style so they never read as
  /// brand surfaces; AA on both themes.
  static const confidenceGreen = Color(0xFF1B7A3D);
  static const confidenceAmber = Color(0xFFB26A00);
  static const confidenceRed = Color(0xFFB3261E);
}

/// Custom tokens beyond [ColorScheme] (header band, finger gradient).
@immutable
class TalkhimikTokens extends ThemeExtension<TalkhimikTokens> {
  const TalkhimikTokens({
    required this.header,
    required this.headerDark,
    required this.headerText,
    required this.fingerLow,
    required this.fingerHigh,
  });

  /// Olive-lime card header band.
  final Color header;

  /// Deep forest green of the diagonal corner.
  final Color headerDark;

  /// AA-safe text on the header band.
  final Color headerText;

  /// Finger gradient endpoints.
  final Color fingerLow;
  final Color fingerHigh;

  static const light = TalkhimikTokens(
    header: AppColors.lime,
    headerDark: AppColors.forest,
    headerText: AppColors.limeText,
    fingerLow: AppColors.fingerLow,
    fingerHigh: AppColors.fingerHigh,
  );

  static const dark = TalkhimikTokens(
    header: Color(0xFF9CBF4D),
    headerDark: Color(0xFF4CAF7D),
    headerText: Color(0xFF1B2908),
    fingerLow: Color(0xFF4A463E),
    fingerHigh: Color(0xFF9CBF4D),
  );

  @override
  TalkhimikTokens copyWith({
    Color? header,
    Color? headerDark,
    Color? headerText,
    Color? fingerLow,
    Color? fingerHigh,
  }) =>
      TalkhimikTokens(
        header: header ?? this.header,
        headerDark: headerDark ?? this.headerDark,
        headerText: headerText ?? this.headerText,
        fingerLow: fingerLow ?? this.fingerLow,
        fingerHigh: fingerHigh ?? this.fingerHigh,
      );

  @override
  TalkhimikTokens lerp(TalkhimikTokens? other, double t) {
    if (other == null) return this;
    return TalkhimikTokens(
      header: Color.lerp(header, other.header, t)!,
      headerDark: Color.lerp(headerDark, other.headerDark, t)!,
      headerText: Color.lerp(headerText, other.headerText, t)!,
      fingerLow: Color.lerp(fingerLow, other.fingerLow, t)!,
      fingerHigh: Color.lerp(fingerHigh, other.fingerHigh, t)!,
    );
  }
}

const _radiusCard = 16.0;
const _radiusControl = 12.0;

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandGreen,
    primary: AppColors.brandGreen,
    secondary: AppColors.forest,
    tertiary: AppColors.lime,
    surface: AppColors.card,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.outlineGray,
    error: AppColors.danger,
    brightness: Brightness.light,
  );
  return _base(scheme, TalkhimikTokens.light).copyWith(
    scaffoldBackgroundColor: AppColors.warmPage,
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3DD68C),
    primary: const Color(0xFF3DD68C),
    secondary: const Color(0xFF4CAF7D),
    tertiary: const Color(0xFF9CBF4D),
    brightness: Brightness.dark,
  );
  return _base(scheme, TalkhimikTokens.dark).copyWith(
    scaffoldBackgroundColor: const Color(0xFF1B1D19),
  );
}

ThemeData _base(ColorScheme scheme, TalkhimikTokens tokens) => ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusCard),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusControl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusControl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusCard),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusCard),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
