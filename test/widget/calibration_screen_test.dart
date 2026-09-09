import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/ui/screens/calibration_screen.dart';

import '../helpers/in_memory_calibration_store.dart';
import '../helpers/in_memory_settings_service.dart';
import '../helpers/test_overrides.dart';

void main() {
  late MockGloveConnection glove;
  late InMemoryCalibrationProfileStore store;

  ProviderContainer makeContainer() {
    glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
      ),
    );
    store = InMemoryCalibrationProfileStore();
    final container = ProviderContainer(
      overrides: testOverrides(
        glove: glove,
        settings: InMemorySettingsService()..participant = 'P-001',
        calibrationStore: store,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalibrationScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('idle screen shows the intro and no profile', (tester) async {
    final container = makeContainer();
    await pump(tester, container);

    expect(find.text(AppStrings.calibrationIntroTitle), findsOneWidget);
    expect(find.text(AppStrings.calibrationNoProfile), findsOneWidget);
    expect(find.byKey(CalibrationScreen.startButtonKey), findsOneWidget);
  });

  testWidgets('prompting advances per rep and aborts back to idle',
      (tester) async {
    final container = makeContainer();
    await pump(tester, container);

    await tester.tap(find.byKey(CalibrationScreen.startButtonKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.calibrationSignPrompt), findsOneWidget);
    expect(find.text('A'), findsOneWidget); // prompt at 72 pt
    expect(find.text('Word 1 of 28'), findsOneWidget);

    // Two reps show two filled dots; the third rep advances the prompt.
    glove.emitGesture(wordId: 1, confidence: 90);
    await tester.pumpAndSettle();
    glove.emitGesture(wordId: 1, confidence: 92);
    await tester.pumpAndSettle();
    expect(find.textContaining('92%'), findsOneWidget);
    expect(find.text('Word 1 of 28'), findsOneWidget);

    glove.emitGesture(wordId: 1, confidence: 94);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Word 2 of 28'), findsOneWidget);

    await tester.tap(find.byKey(CalibrationScreen.abortButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calibrationIntroTitle), findsOneWidget);
    expect(store.saved, isNull);
  });

  testWidgets('a full run saves a profile and Done returns to the summary',
      (tester) async {
    final container = makeContainer();
    await pump(tester, container);

    await tester.tap(find.byKey(CalibrationScreen.startButtonKey));
    await tester.pumpAndSettle();

    // 28 letters × 3 reps.
    for (var wordId = 1; wordId <= 28; wordId++) {
      for (var rep = 0; rep < 3; rep++) {
        glove.emitGesture(wordId: wordId, confidence: 90 + rep);
        await tester.pumpAndSettle();
      }
    }

    expect(find.text(AppStrings.calibrationSavedTitle), findsOneWidget);
    expect(find.textContaining('28 words'), findsOneWidget);
    expect(store.saved, isNotNull);
    expect(store.saved!.stats, hasLength(28));

    await tester.tap(find.byKey(CalibrationScreen.doneButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.calibrationProfileSummary), findsOneWidget);
    expect(find.textContaining('P-001'), findsOneWidget);
  });
}
