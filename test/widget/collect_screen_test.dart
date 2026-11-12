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

    // App bar + header band both show the title (design refresh).
    expect(find.text(AppStrings.recordModeTitle), findsNWidgets(2));
    expect(find.text(AppStrings.recordStart), findsOneWidget);
    // The coverage card sits above the sessions list now — scroll to it
    // (the outer ListView is the first Scrollable; TextFields own one too).
    await tester.scrollUntilVisible(
      find.text(AppStrings.datasetSessions),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

  /// The coverage card added a lot of vertical content — give these tests
  /// a tall viewport so the whole list is laid out at once.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the coverage card shows the letter grid, REST chip, summary '
      'and hint', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.coverageTitle), findsOneWidget);
    expect(find.text('A · 0'), findsOneWidget);
    expect(find.text('REST · 0'), findsOneWidget);
    // J and Z exist as chips (marked later, not excluded from the grid).
    expect(find.text('J · 0'), findsOneWidget);
    expect(find.text('Z · 0'), findsOneWidget);
    expect(find.text(AppStrings.coverageHint), findsOneWidget);
    expect(find.textContaining('of 27 letters ready'), findsOneWidget);
  });

  testWidgets('tapping a coverage chip preselects the label and the REST '
      'chip stores `_rest`', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('A · 0'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'A'), findsOneWidget);

    await tester.tap(find.text('REST · 0'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '_rest'), findsOneWidget);
  });

  testWidgets('the REST picker item exists in the label dropdown',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // The menu scrolls internally — REST is the last item.
    await tester.scrollUntilVisible(
      find.text(AppStrings.restLabelItem),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(AppStrings.restLabelItem), findsOneWidget);
  });

  testWidgets('share-all is disabled with a reason when there is no data',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('share-all-button')));
    expect(button.onPressed, isNull);
    expect(find.text(AppStrings.shareAllNoData), findsOneWidget);
  });
}
