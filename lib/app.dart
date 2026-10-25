import 'package:flutter/material.dart';

import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/calibration_screen.dart';
import 'ui/screens/collect_screen.dart';
import 'ui/screens/export_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/live_screen.dart';
import 'ui/screens/settings_screen.dart';

class TalkhimikApp extends StatelessWidget {
  const TalkhimikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: buildLightTheme(),
      // Light is the primary theme (design refresh); dark remains
      // selectable via the same hue family.
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      routes: {
        '/live': (_) => const LiveScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/export': (_) => const ExportScreen(),
        '/calibration': (_) => const CalibrationScreen(),
        '/collect': (_) => const CollectScreen(),
      },
    );
  }
}
