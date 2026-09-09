import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/ui/screens/settings_screen.dart';

import '../helpers/fake_tts_service.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';
import '../helpers/test_overrides.dart';

void main() {
  late InMemorySettingsService settings;
  late InMemoryLogStore logStore;
  late FakeTtsService tts;

  ProviderContainer makeContainer() {
    settings = InMemorySettingsService();
    logStore = InMemoryLogStore();
    tts = FakeTtsService();
    final container = ProviderContainer(
      overrides: testOverrides(settings: settings, logStore: logStore, tts: tts),
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    final container = makeContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // Loads TTS settings + the platform voice list (the app bootstrap does
    // this in main.dart).
    await container.read(ttsControllerProvider.notifier).initialize();
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('language toggle updates the transcript language and persists',
      (tester) async {
    final container = await pumpSettings(tester);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(transcriptControllerProvider).language, 'en');
    expect(settings.language, 'en');
    expect(tts.lastLanguage, 'en-US');
  });

  testWidgets('mute switch updates TTS controller and persists',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Mute speech'));
    await tester.pumpAndSettle();

    expect(settings.muted, isTrue);
  });

  testWidgets('large-text toggle reaches the transcript controller',
      (tester) async {
    final container = await pumpSettings(tester);
    expect(container.read(transcriptControllerProvider).largeText, isTrue);

    await tester.ensureVisible(find.text('Large signer-facing text'));
    await tester.tap(find.text('Large signer-facing text'));
    await tester.pumpAndSettle();

    expect(container.read(transcriptControllerProvider).largeText, isFalse);
    expect(await settings.largeText(), isFalse);
  });

  testWidgets('participant id + consent write an anonymized profile to the '
      'log store (FR-13)', (tester) async {
    await pumpSettings(tester);

    await tester.enterText(
        find.byKey(const Key('participant-id-field')), 'P-042');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('consent-switch')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-switch')));
    await tester.pumpAndSettle();

    expect(settings.participant, 'P-042');
    expect(await settings.consentGiven(), isTrue);
    final profile = logStore.participants['P-042'];
    expect(profile, isNotNull);
    expect(profile!.consentGiven, isTrue);
    expect(profile.consentDate, isNotNull);
    // Anonymized: the profile carries no name field at all.
  });

  testWidgets('voice dropdown offers the engine voices', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Filipino voice'), findsOneWidget);
  });
}
