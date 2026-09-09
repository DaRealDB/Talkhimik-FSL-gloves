import 'package:flutter/material.dart';

import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';

class TalkhimikApp extends StatelessWidget {
  const TalkhimikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: buildLightTheme(),
      // Dark-first per the design decisions; light remains selectable.
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
