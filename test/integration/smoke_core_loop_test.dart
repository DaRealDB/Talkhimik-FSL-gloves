import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/ui/screens/home_screen.dart';

import '../helpers/fake_tts_service.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';
import '../helpers/test_overrides.dart';

/// The whole SRS end-to-end data flow minus radio and cloud:
/// glove (mock) → decode → bubble → TTS → log (steps 3–7).
void main() {
  testWidgets('mock glove gestures flow into bubbles, TTS, and the log',
      (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
      ),
    );
    final tts = FakeTtsService();
    final logStore = InMemoryLogStore();
    final settings = InMemorySettingsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          glove: glove,
          tts: tts,
          logStore: logStore,
          settings: settings,
        ),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The home screen auto-connects the mock; its zero-length connect
    // delays complete during the pumps above (awaiting them directly would
    // deadlock: testWidgets' fake clock only advances while pumping).
    expect(glove, isNotNull);
    glove.emitGesture(wordId: 1, confidence: 95); // A
    glove.emitGesture(wordId: 100, confidence: 88); // Kumusta
    glove.emitGesture(wordId: 5, confidence: 45); // E
    await tester.pumpAndSettle();

    // FR-1: bubbles in arrival order with the Filipino text. ('Kumusta'
    // also appears once as a saved-phrase chip, hence findsWidgets.)
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Kumusta'), findsWidgets);
    expect(find.text('E'), findsOneWidget);

    // FR-2: TTS spoke each accepted result.
    expect(tts.spoken, ['A', 'Kumusta', 'E']);

    // FR-10: every event is logged with the FR-10 schema fields.
    expect(logStore.events, hasLength(3));
    final first = logStore.events.first;
    expect(first.wordId, 1);
    expect(first.filipinoText, 'A');
    expect(first.confidence, 95);
    expect(first.confidenceLevel, 'green');
    expect(first.sessionId, isNotEmpty);
    expect(first.latencyMs, greaterThanOrEqualTo(0));

    // FR-4: red event carries a red level.
    expect(logStore.events.last.confidenceLevel, 'red');
  });
}
