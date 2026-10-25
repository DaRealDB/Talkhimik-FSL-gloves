import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/app.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/mock_glove_connection.dart';
import 'package:talkhimik_app/ui/screens/home_screen.dart';
import 'package:talkhimik_app/ui/widgets/device_status_bar.dart';

import '../helpers/fake_tts_service.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';
import '../helpers/test_overrides.dart';

void main() {
  testWidgets('renders status bar, transcript placeholder, and reply panel',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeviceStatusBar), findsOneWidget);
    expect(find.text(AppStrings.emptyTranscript), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a gesture produces a bubble with a confidence badge',
      (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
        telemetryEnabled: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(glove: glove),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    glove.emitGesture(wordId: 104, confidence: 93); // Salamat
    await tester.pumpAndSettle();

    expect(find.text('Salamat'), findsOneWidget);
    expect(find.text('93%'), findsOneWidget);
    expect(find.text(AppStrings.emptyTranscript), findsNothing);
  });

  testWidgets('reply panel adds a large partner bubble for the signer',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kumusta ka na?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Kumusta ka na?'), findsOneWidget);
    // The partner bubble renders in the large-text style (NFR-7).
    final text = tester.widget<Text>(find.text('Kumusta ka na?'));
    expect(text.style?.fontSize, 22);
    // Field cleared after sending.
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
  });

  testWidgets('clearing the transcript keeps logged events (FR-3 vs FR-10)',
      (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
        telemetryEnabled: false,
      ),
    );
    final logStore = InMemoryLogStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(glove: glove, logStore: logStore),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    glove.emitGesture(wordId: 1, confidence: 95);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(logStore.events, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(logStore.events, hasLength(1)); // logs untouched
  });

  testWidgets('mute stops TTS but keeps the transcript flowing',
      (tester) async {
    final glove = MockGloveConnection(
      config: const MockGloveConfig(
        connectStepDelay: Duration.zero,
        gestureCadence: Duration(milliseconds: 10),
        telemetryEnabled: false,
      ),
    );
    final tts = FakeTtsService();
    final settings = InMemorySettingsService()..muted = true;
    final container = ProviderContainer(
      overrides: testOverrides(glove: glove, tts: tts, settings: settings),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // TtsController only honors mute after initialize() reads settings.
    await container.read(ttsControllerProvider.notifier).initialize();
    await tester.pumpAndSettle();

    glove.emitGesture(wordId: 1, confidence: 95);
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget); // transcript unaffected
    expect(tts.spoken, isEmpty); // FR-2 mute respected
  });

  testWidgets('app bar navigates to calibration and record mode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: const TalkhimikApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigation (step 4): Calibration lives under the More destination;
    // Record is a bottom-nav destination.
    await tester.tap(find.text(AppStrings.moreTab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.calibrationTitle).first);
    await tester.pumpAndSettle();
    // App bar + header band both show the title (design refresh).
    expect(find.text(AppStrings.calibrationTitle), findsNWidgets(2));

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.recordModeTitle).first);
    await tester.pumpAndSettle();
    // App bar + header band + the bottom-nav label (3 occurrences).
    expect(find.text(AppStrings.recordModeTitle), findsNWidgets(3));
  });
}
