import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/data_collection_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/ui/screens/collect_screen.dart';

import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';
import '../helpers/test_overrides.dart';

void main() {
  late MockGloveConnection glove;
  late InMemoryLogStore logStore;

  ProviderContainer makeContainer({
    InMemorySettingsService? settings,
    int repsPerPrompt = 1,
  }) {
    glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
      ),
    );
    logStore = InMemoryLogStore();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(
          glove: glove,
          logStore: logStore,
          settings: settings ??
              (InMemorySettingsService()
                ..participant = 'P-001'
                ..consent = true),
        ),
        dataCollectionControllerProvider
            .overrideWith(() => DataCollectionController(
                repsPerPrompt: repsPerPrompt)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CollectScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('idle screen shows the gate state and intro', (tester) async {
    final container = makeContainer();
    await pump(tester, container);

    expect(find.text(AppStrings.recordIntroTitle), findsOneWidget);
    expect(find.text('Participant: P-001'), findsOneWidget);
    expect(find.text('Consent: given'), findsOneWidget);
    expect(find.byKey(CollectScreen.startButtonKey), findsOneWidget);
  });

  testWidgets('start without consent shows the NFR-8 gate', (tester) async {
    final container = makeContainer(
      settings: InMemorySettingsService()
        ..participant = 'P-001'
        ..consent = false,
    );
    await pump(tester, container);

    await tester.tap(find.byKey(CollectScreen.startButtonKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.recordNeedsConsent), findsOneWidget);
    expect(find.text(AppStrings.recordSignPrompt), findsNothing);
  });

  testWidgets('prompting records labeled samples; skip and abort work',
      (tester) async {
    final container = makeContainer(repsPerPrompt: 2);
    await pump(tester, container);

    await tester.tap(find.byKey(CollectScreen.startButtonKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.recordSignPrompt), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.textContaining('Label 1 of 28'), findsOneWidget);

    // Two samples complete label A and advance to B.
    glove.emitGesture(wordId: 1, confidence: 95);
    await tester.pumpAndSettle();
    glove.emitGesture(wordId: 2, confidence: 88);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.textContaining('Label 2 of 28'), findsOneWidget);
    expect(logStore.events, hasLength(2));
    expect(logStore.events[1].originalWordId, 2); // observed word preserved

    // Skip B → C, no rows recorded for B.
    await tester.tap(find.byKey(CollectScreen.skipButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
    expect(find.textContaining('Label 3 of 28'), findsOneWidget);
    expect(logStore.events, hasLength(2));

    await tester.tap(find.byKey(CollectScreen.abortButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recordIntroTitle), findsOneWidget);
    expect(logStore.events, hasLength(2)); // recorded rows stay
  });

  testWidgets('a full run ends with the summary and rows in the store',
      (tester) async {
    final container = makeContainer(repsPerPrompt: 1);
    await pump(tester, container);

    await tester.tap(find.byKey(CollectScreen.startButtonKey));
    await tester.pumpAndSettle();

    for (var wordId = 1; wordId <= 28; wordId++) {
      glove.emitGesture(wordId: wordId, confidence: 90);
      await tester.pumpAndSettle();
    }

    expect(find.text(AppStrings.recordDoneTitle), findsOneWidget);
    expect(find.text('28 samples · 0 skipped'), findsOneWidget);
    expect(find.textContaining('S-'), findsOneWidget);
    expect(find.text(AppStrings.recordLogsHint), findsOneWidget);
    expect(logStore.events, hasLength(28));

    await tester.tap(find.byKey(CollectScreen.doneButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recordIntroTitle), findsOneWidget);
  });
}
