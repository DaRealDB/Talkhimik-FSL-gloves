import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/ui/screens/collect_screen.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';
import '../helpers/in_memory_settings_service.dart';

void main() {
  late Directory dir;
  late InMemorySettingsService settings;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('talkhimik_collect_test');
    settings = InMemorySettingsService();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Widget wrap() => ProviderScope(
        overrides: [
          gloveConnectionProvider.overrideWithValue(FakeGloveConnection()),
          rightGloveConnectionProvider
              .overrideWithValue(FakeGloveConnection()),
          settingsServiceProvider.overrideWithValue(settings),
          calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
          datasetDirectoryProvider.overrideWithValue(Future.value(dir)),
        ],
        child: const MaterialApp(home: CollectScreen()),
      );

  testWidgets('idle screen shows the label input, record button, and the '
      'sessions list header', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.recordModeTitle), findsOneWidget);
    expect(find.text(AppStrings.recordStart), findsOneWidget);
    expect(find.text(AppStrings.datasetSessions), findsOneWidget);
  });

  testWidgets('the consent gate shows the NFR-8 message and stays idle',
      (tester) async {
    settings.participant = 'P-001';
    settings.consent = false;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.recordStart));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.recordNeedsConsent), findsOneWidget);
    expect(find.text(AppStrings.datasetRecording), findsNothing);
  });

  testWidgets('starting with consent records and shows the stop control',
      (tester) async {
    settings.participant = 'P-001';
    settings.consent = true;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.recordStart));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.recordAbort), findsOneWidget);
    expect(find.textContaining(AppStrings.datasetRecording), findsOneWidget);
  });
}
