import 'package:flutter/material.dart';

import 'motion.dart';

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

/// App-specific text styles (typography pass): the product's main text
/// (transcriptWord) is the largest, most legible style; live numbers use
/// tabular figures so digits never jitter.
@immutable
class TalkhimikText extends ThemeExtension<TalkhimikText> {
  const TalkhimikText({
    required this.bandTitle,
    required this.transcriptWord,
    required this.metric,
    required this.id,
    required this.caption,
    required this.chip,
    required this.badge,
  });

  final TextStyle? bandTitle;
  final TextStyle? transcriptWord;
  final TextStyle? metric;
  final TextStyle? id;
  final TextStyle? caption;
  final TextStyle? chip;
  final TextStyle? badge;

  /// Plain fallback for contexts without a registered theme (tests that
  /// pump under a default MaterialApp).
  static const fallback = TalkhimikText(
    bandTitle: TextStyle(fontWeight: FontWeight.w700),
    transcriptWord: TextStyle(fontWeight: FontWeight.w600),
    metric: TextStyle(),
    id: TextStyle(),
    caption: TextStyle(),
    chip: TextStyle(),
    badge: TextStyle(fontWeight: FontWeight.w700),
  );

  static TalkhimikText of(BuildContext context) =>
      Theme.of(context).extension<TalkhimikText>() ?? fallback;

  @override
  TalkhimikText copyWith({
    TextStyle? bandTitle,
    TextStyle? transcriptWord,
    TextStyle? metric,
    TextStyle? id,
    TextStyle? caption,
    TextStyle? chip,
    TextStyle? badge,
  }) =>
      TalkhimikText(
        bandTitle: bandTitle ?? this.bandTitle,
        transcriptWord: transcriptWord ?? this.transcriptWord,
        metric: metric ?? this.metric,
        id: id ?? this.id,
        caption: caption ?? this.caption,
        chip: chip ?? this.chip,
        badge: badge ?? this.badge,
      );

  @override
  TalkhimikText lerp(TalkhimikText? other, double t) {
    if (other == null) return this;
    return TalkhimikText(
      bandTitle: TextStyle.lerp(bandTitle, other.bandTitle, t),
      transcriptWord:
          TextStyle.lerp(transcriptWord, other.transcriptWord, t),
      metric: TextStyle.lerp(metric, other.metric, t),
      id: TextStyle.lerp(id, other.id, t),
      caption: TextStyle.lerp(caption, other.caption, t),
      chip: TextStyle.lerp(chip, other.chip, t),
      badge: TextStyle.lerp(badge, other.badge, t),
    );
  }
}

/// Inter type scale (bundled assets, typography pass). Sizes stay fixed —
/// accessibility text scale is applied by MediaQuery, never by shrinking
/// these values.
TextTheme _buildTextTheme(Color onSurface) => const TextTheme(
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, height: 44 / 36, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 36 / 28),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 32 / 24),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 28 / 22),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16, letterSpacing: 0.15),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14, letterSpacing: 0.25),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12, letterSpacing: 0.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12, letterSpacing: 0.5),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 16 / 11, letterSpacing: 0.5),
    );

TalkhimikText _buildTalkhimikText() => const TalkhimikText(
      bandTitle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 20 / 16,
          letterSpacing: 0.15),
      transcriptWord: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 40 / 32,
          letterSpacing: -0.25),
      metric: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          fontFeatures: [FontFeature.tabularFigures()]),
      id: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 18 / 13,
          fontFeatures: [FontFeature.tabularFigures()]),
      caption: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12),
      chip: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 16 / 11),
      badge: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 16 / 11),
    );

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
      fontFamily: 'Inter',
      textTheme: _buildTextTheme(scheme.onSurface),
      useMaterial3: true,
      extensions: [tokens, _buildTalkhimikText(), TalkhimikMotion.values],
      // Shared fade-through page transition (≤ 280 ms) + brand-tinted
      // ripples for the pill microinteractions.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      splashColor: AppColors.brandGreen.withValues(alpha: 0.15),
      highlightColor: AppColors.brandGreen.withValues(alpha: 0.08),
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        // Pill tab buttons (reference style): L / R and navigation tabs.
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
