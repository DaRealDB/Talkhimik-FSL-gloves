import 'package:flutter/material.dart';

import 'motion.dart';

/// Talkhimik design tokens v3 (approved 2026-10) — the three signature
/// blues (sky / azure / navy) on a clean white field, 45° diagonal slab
/// geometry, soft navy-tinted shadows. Supersedes the green/olive palette;
/// the token ARCHITECTURE (ColorScheme + ThemeExtensions) is unchanged.
///
/// AA rules baked in: sky #54C5F8 and azure #29B6F6 are FILLS only
/// (≈1.9:1 / ≈2.3:1 on white); anything on them uses navy text. Every
/// card/input carries the 1 dp #3E7196 hairline (4.4:1 vs white) so the
/// background → card → chip depth step is always legible.
class AppColors {
  AppColors._();

  // Brand (light)
  static const navy = Color(0xFF01579B); // primary, active states
  static const navyText = Color(0xFF0B2540); // primary text (14.5:1)
  static const azure = Color(0xFF29B6F6); // secondary — fills only
  static const sky = Color(0xFF54C5F8); // tertiary — decoration only
  static const fold = Color(0xFF013A6B); // fold-shadow core
  static const tintSky = Color(0xFFF3F9FD); // card surface
  static const tintSkyDeep = Color(0xFFE6F3FB); // chips / inputs
  static const textSecondary = Color(0xFF36536E); // 8.0:1 on white
  static const textTertiary = Color(0xFF5F7A91); // 4.6:1 on white
  static const outlineBlue = Color(0xFF3E7196); // hairlines (4.4:1)
  static const outlineSoft = Color(0xFF9FC2D9); // decorative dividers
  static const shadowBlue = Color(0x1F01579B); // rgba(1,87,155,0.12)

  // Dark
  static const darkBg = Color(0xFF06182B);
  static const darkSurface = Color(0xFF0C2540);
  static const darkSurfaceVariant = Color(0xFF123456);
  static const darkOutline = Color(0xFF5B87AB);

  // Semantic
  static const success = Color(0xFF1B7A3D);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFB3261E);
  static const infoTeal = Color(0xFF00796B); // info ≠ brand blue

  /// Confidence badge colors (FR-4): green/amber/red + ✓/◐/! glyphs.
  static const confidenceGreen = Color(0xFF1B7A3D);
  static const confidenceAmber = Color(0xFFB26A00);
  static const confidenceRed = Color(0xFFB3261E);

  // Finger gradient (2-stop approximation; the 4-stop version lands with
  // the hand re-skin).
  static const fingerLow = Color(0xFFD6EEFB);
  static const fingerHigh = Color(0xFF54C5F8);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky, azure],
  );

  static const deepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [azure, navy],
  );

  /// Soft inner shadow where navy meets azure (the logo's fold).
  static const foldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [fold, Color(0x00013A6B)],
  );
}

/// Custom tokens beyond [ColorScheme] (slab colors, finger gradient).
@immutable
class TalkhimikTokens extends ThemeExtension<TalkhimikTokens> {
  const TalkhimikTokens({
    required this.header,
    required this.headerDark,
    required this.headerText,
    required this.fingerLow,
    required this.fingerHigh,
  });

  /// Sky — diagonal slab / header fills.
  final Color header;

  /// Navy — outline, accents, fold shadow.
  final Color headerDark;

  /// AA-safe text on the slab (navy on sky).
  final Color headerText;

  /// Finger gradient endpoints.
  final Color fingerLow;
  final Color fingerHigh;

  static const light = TalkhimikTokens(
    header: AppColors.sky,
    headerDark: AppColors.navy,
    headerText: AppColors.navyText,
    fingerLow: AppColors.fingerLow,
    fingerHigh: AppColors.fingerHigh,
  );

  static const dark = TalkhimikTokens(
    header: AppColors.sky,
    headerDark: AppColors.azure,
    headerText: AppColors.darkBg,
    fingerLow: AppColors.fingerLow,
    fingerHigh: AppColors.sky,
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

/// App-specific text styles (typography pass): the product's main text
/// (transcriptHero) is the largest, most legible style; live numbers use
/// tabular figures so digits never jitter.
@immutable
class TalkhimikText extends ThemeExtension<TalkhimikText> {
  const TalkhimikText({
    required this.bandTitle,
    required this.transcriptWord,
    required this.transcriptHero,
    required this.transcriptHistory,
    required this.transcriptHistoryOld,
    required this.display,
    required this.metric,
    required this.id,
    required this.caption,
    required this.chip,
    required this.badge,
  });

  final TextStyle? bandTitle;

  /// Standard signed-bubble word.
  final TextStyle? transcriptWord;

  /// HERO: the latest recognized sign — the largest text in the app
  /// (40–56 sp mobile), leading ~1.05, display weight.
  final TextStyle? transcriptHero;

  /// Earlier signs step down in size and opacity (100 → 70 → 50 %).
  final TextStyle? transcriptHistory;
  final TextStyle? transcriptHistoryOld;

  /// Display for calibration prompts and success states.
  final TextStyle? display;

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
    transcriptHero: TextStyle(fontWeight: FontWeight.w700),
    transcriptHistory: TextStyle(fontWeight: FontWeight.w600),
    transcriptHistoryOld: TextStyle(fontWeight: FontWeight.w500),
    display: TextStyle(fontWeight: FontWeight.w700),
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
    TextStyle? transcriptHero,
    TextStyle? transcriptHistory,
    TextStyle? transcriptHistoryOld,
    TextStyle? display,
    TextStyle? metric,
    TextStyle? id,
    TextStyle? caption,
    TextStyle? chip,
    TextStyle? badge,
  }) =>
      TalkhimikText(
        bandTitle: bandTitle ?? this.bandTitle,
        transcriptWord: transcriptWord ?? this.transcriptWord,
        transcriptHero: transcriptHero ?? this.transcriptHero,
        transcriptHistory: transcriptHistory ?? this.transcriptHistory,
        transcriptHistoryOld:
            transcriptHistoryOld ?? this.transcriptHistoryOld,
        display: display ?? this.display,
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
      transcriptHero:
          TextStyle.lerp(transcriptHero, other.transcriptHero, t),
      transcriptHistory:
          TextStyle.lerp(transcriptHistory, other.transcriptHistory, t),
      transcriptHistoryOld: TextStyle.lerp(
          transcriptHistoryOld, other.transcriptHistoryOld, t),
      display: TextStyle.lerp(display, other.display, t),
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
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 44 / 36, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 40 / 32),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20, letterSpacing: 0.1),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 22 / 16, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16, letterSpacing: 0.25),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14, letterSpacing: 0.25),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12, letterSpacing: 0.4),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 20 / 16, letterSpacing: 0.1),
      labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 16 / 14, letterSpacing: 0.25),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12, letterSpacing: 0.25),
    );

TalkhimikText _buildTalkhimikText() => const TalkhimikText(
      bandTitle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 22 / 18,
          letterSpacing: 0.1),
      transcriptWord: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 30 / 24,
          letterSpacing: -0.25),
      // HERO: the latest recognized sign (40–56 sp mobile, leading ~1.05).
      transcriptHero: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          height: 46 / 44,
          letterSpacing: -0.5),
      transcriptHistory: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 30 / 24,
          letterSpacing: -0.25),
      transcriptHistoryOld: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 24 / 18,
          letterSpacing: -0.15),
      display: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          height: 46 / 44,
          letterSpacing: -0.5),
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
      chip: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12),
      badge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12),
    );

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.azure,
    onSecondary: AppColors.navyText,
    tertiary: AppColors.sky,
    onTertiary: AppColors.navyText,
    surface: AppColors.tintSky,
    onSurface: AppColors.navyText,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.outlineBlue,
    outlineVariant: AppColors.outlineSoft,
    error: AppColors.danger,
    brightness: Brightness.light,
  );
  return _base(scheme, TalkhimikTokens.light).copyWith(
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 64,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        shape: const StadiumBorder(),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.navy,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF54C5F8),
    primary: const Color(0xFF54C5F8),
    onPrimary: const Color(0xFF06182B),
    secondary: const Color(0xFF29B6F6),
    onSecondary: const Color(0xFF06182B),
    tertiary: const Color(0xFF29B6F6),
    brightness: Brightness.dark,
    surface: const Color(0xFF0C2540),
    onSurface: Colors.white,
    outline: const Color(0xFF5B87AB),
    error: const Color(0xFFF2B8B5),
  );
  return _base(scheme, TalkhimikTokens.dark).copyWith(
    scaffoldBackgroundColor: const Color(0xFF06182B),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF06182B),
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF54C5F8),
        foregroundColor: const Color(0xFF06182B),
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF54C5F8),
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: const BorderSide(color: Color(0xFF54C5F8), width: 1.5),
        shape: const StadiumBorder(),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0C2540),
      selectedItemColor: Color(0xFF54C5F8),
      unselectedItemColor: Color(0xFF5F7A91),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
  );
}

ThemeData _base(ColorScheme scheme, TalkhimikTokens tokens) => ThemeData(
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: _buildTextTheme(scheme.onSurface),
      useMaterial3: true,
      extensions: [tokens, _buildTalkhimikText(), TalkhimikMotion.values],
      // Shared fade-through page transition (≤ 280 ms) + azure ripples.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      splashColor: AppColors.azure.withValues(alpha: 0.2),
      highlightColor: AppColors.azure.withValues(alpha: 0.08),
      // Cards: tinted glass base, soft navy-tinted shadow, and the 1 dp
      // hairline that carries the background → card depth step (4.4:1).
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: AppColors.shadowBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        // 1.5 dp azure focus border — never a heavy dark outline.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.secondary, width: 1.5),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 24,
          minimumSize: const Size(48, 48),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
