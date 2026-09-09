import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';
import 'package:talkhimik_app/ui/screens/home_screen.dart';

import '../helpers/fake_tts_service.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/test_overrides.dart';

/// Full FR-5 flow: red bubble → tap → top-3 sheet → one tap corrects the
/// transcript and logs a correction row.
void main() {
  testWidgets('tapping a low-confidence bubble offers alternatives and '
      'correcting updates bubble + log', (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
      ),
    );
    final logStore = InMemoryLogStore();
    final tts = FakeTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          glove: glove,
          logStore: logStore,
          tts: tts,
        ),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // A red 'A' with top-3 alternatives attached (like the real glove's
    // extended packet will carry).
    glove.emitGesture(
      wordId: 1,
      confidence: 50,
      alternatives: const [
        AlternativePrediction(wordId: 5, confidence: 68), // E
        AlternativePrediction(wordId: 9, confidence: 55), // I
        AlternativePrediction(wordId: 17, confidence: 45), // O
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // Tap the bubble → the sheet appears with the three options.
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Did you mean…'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);

    // One tap corrects.
    await tester.tap(find.text('E'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('corrected'), findsOneWidget);

    // Cohen's Kappa gold: a source=correction row with the original id.
    expect(logStore.events, hasLength(2)); // recognition + correction
    final correction = logStore.events.last;
    expect(correction.source, 'correction');
    expect(correction.corrected, isTrue);
    expect(correction.originalWordId, 1);
    expect(correction.wordId, 5);
    expect(tts.spoken.last, 'E');
  });

  testWidgets('a green bubble tap re-reads instead of opening the sheet',
      (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
      ),
    );
    final tts = FakeTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(glove: glove, tts: tts),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    glove.emitGesture(wordId: 104, confidence: 95); // Salamat
    await tester.pumpAndSettle();
    final spokenBefore = tts.spoken.length;

    await tester.tap(find.text('Salamat'));
    await tester.pumpAndSettle();

    expect(find.text('Did you mean…'), findsNothing);
    expect(tts.spoken.length, spokenBefore + 1);
  });

  testWidgets('saved phrase chip speaks and echoes into the transcript '
      '(FR-6)', (tester) async {
    final tts = FakeTtsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(tts: tts),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kumusta'));
    await tester.pumpAndSettle();

    expect(tts.spoken, contains('Kumusta'));
    // The chip label and the transcript bubble now both exist.
    expect(find.text('Kumusta'), findsWidgets);
  });
}
