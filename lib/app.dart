import 'package:flutter/material.dart';

import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/calibration_screen.dart';
import 'ui/screens/collect_screen.dart';
import 'ui/screens/export_screen.dart';
import 'ui/screens/live_screen.dart';
import 'ui/screens/more_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/shell.dart';

class TalkhimikApp extends StatelessWidget {
  const TalkhimikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: buildLightTheme(),
      // Dark mode follows the device (navy-derived dark theme from the
      // same blue family); light stays the default when the device asks.
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
      routes: {
        '/live': (_) => const LiveScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/export': (_) => const ExportScreen(),
        '/calibration': (_) => const CalibrationScreen(),
        '/collect': (_) => const CollectScreen(),
        '/more': (_) => const MoreScreen(),
      },
    );
  }
}
