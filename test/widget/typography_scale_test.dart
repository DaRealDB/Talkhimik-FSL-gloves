import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/theme/app_theme.dart';
import 'package:talkhimik_app/ui/screens/calibration_screen.dart';
import 'package:talkhimik_app/ui/screens/collect_screen.dart';
import 'package:talkhimik_app/ui/screens/export_screen.dart';
import 'package:talkhimik_app/ui/screens/home_screen.dart';
import 'package:talkhimik_app/ui/screens/live_screen.dart';
import 'package:talkhimik_app/ui/screens/settings_screen.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';
import '../helpers/test_overrides.dart';

/// Typography pass acceptance: key screens render without overflow at
/// text scales 1.0, 1.3, and 2.0 on a 360 dp phone (NFR-7).
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('talkhimik_scale_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  void usePhoneWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> expectNoOverflow(WidgetTester tester, Widget screen,
      {required double textScale, List<Override>? overrides}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides ?? testOverrides(),
      child: MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'overflow at text scale $textScale');
  }

  final scales = [1.0, 1.3, 2.0];

  for (final scale in scales) {
    testWidgets('Home renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(tester, const HomeScreen(), textScale: scale);
    });

    testWidgets('Live renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(
        tester,
        const LiveScreen(),
        textScale: scale,
        overrides: [
          gloveConnectionProvider
              .overrideWithValue(FakeGloveConnection()),
          rightGloveConnectionProvider
              .overrideWithValue(FakeGloveConnection()),
          calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
        ],
      );
    });

    testWidgets('Calibration renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(tester, const CalibrationScreen(),
          textScale: scale);
    });

    testWidgets('Collect renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(
        tester,
        const CollectScreen(),
        textScale: scale,
        overrides: [
          ...testOverrides(),
          datasetDirectoryProvider.overrideWithValue(Future.value(dir)),
        ],
      );
    });

    testWidgets('Export renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(tester, const ExportScreen(), textScale: scale);
    });

    testWidgets('Settings renders without overflow at scale $scale',
        (tester) async {
      usePhoneWindow(tester);
      await expectNoOverflow(tester, const SettingsScreen(), textScale: scale);
    });
  }
}
