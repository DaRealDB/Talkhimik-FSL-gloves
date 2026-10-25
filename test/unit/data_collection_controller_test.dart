import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/data_collection_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';

void main() {
  late FakeGloveConnection glove;
  late InMemoryLogStore logStore;
  late InMemorySettingsService settings;

  ProviderContainer makeContainer({int repsPerPrompt = 2}) {
    glove = FakeGloveConnection();
    logStore = InMemoryLogStore();
    settings = InMemorySettingsService()
      ..participant = 'P-001'
      ..consent = true;
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(glove),
        logStoreProvider.overrideWithValue(logStore),
        settingsServiceProvider.overrideWithValue(settings),
        dataCollectionControllerProvider
            .overrideWith(() => DataCollectionController(
                repsPerPrompt: repsPerPrompt)),
      ],
    );
    addTearDown(container.dispose);
    container.read(dataCollectionControllerProvider);
    return container;
  }

  Future<void> emit(GestureResultPacket packet) async {
    glove.emitGesture(packet);
    await pumpEventQueue();
  }

  GestureResultPacket packet(int wordId, int confidence) =>
      GestureResultPacket(
        wordId: wordId,
        confidence: confidence,
        gloveTimestampMs: 1000,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1200),
      );

  test('gates on missing participant id, then on missing consent',
      () async {
    final c = makeContainer();
    settings.participant = '';
    settings.consent = false;
    await c.read(dataCollectionControllerProvider.notifier).start();
    expect(c.read(dataCollectionControllerProvider).error,
        AppStrings.recordNeedsParticipant);

    settings.participant = 'P-001';
    await c.read(dataCollectionControllerProvider.notifier).start();
    expect(c.read(dataCollectionControllerProvider).error,
        AppStrings.recordNeedsConsent);
    expect(c.read(dataCollectionControllerProvider).phase,
        CollectionPhase.idle);
    expect(glove.commands, isEmpty);
  });

  test('records labeled rows with the observed word preserved', () async {
    final c = makeContainer(repsPerPrompt: 2);
    await c.read(dataCollectionControllerProvider.notifier).start();

    final state = c.read(dataCollectionControllerProvider);
    expect(state.phase, CollectionPhase.prompting);
    expect(state.sessionId, startsWith('S-'));
    expect(state.participantId, 'P-001');
    expect(glove.commands, contains(AppCommand.setRate));

    // Word 1: one match, one mismatch (signer signed B during the A prompt).
    await emit(packet(1, 95));
    await emit(packet(2, 88));
    // Word 2: two matching samples complete the label.
    await emit(packet(2, 90));
    await emit(packet(2, 91));

    expect(logStore.events, hasLength(4));
    expect(logStore.events.every((e) => e.source == 'collection'), isTrue);
    expect(logStore.events.every((e) => e.sessionId == state.sessionId),
        isTrue);
    expect(logStore.events[0].wordId, 1); // label A
    expect(logStore.events[0].originalWordId, isNull); // observed == label
    expect(logStore.events[1].wordId, 1); // label A...
    expect(logStore.events[1].originalWordId, 2); // ...observed B
    expect(logStore.events[2].wordId, 2);
    expect(logStore.events[2].originalWordId, isNull);

    // Two labels in, current prompt advanced to word 3 (C).
    expect(
        c.read(dataCollectionControllerProvider).currentPrompt?.wordId, 3);
    expect(c.read(dataCollectionControllerProvider).counts[1], 2);
    expect(c.read(dataCollectionControllerProvider).counts[2], 2);
  });

  test('skip advances the label without recording rows', () async {
    final c = makeContainer();
    await c.read(dataCollectionControllerProvider.notifier).start();
    await emit(packet(1, 95));

    c.read(dataCollectionControllerProvider.notifier).skip();
    final state = c.read(dataCollectionControllerProvider);
    expect(state.currentPrompt?.wordId, 2);
    expect(state.skippedCount, 1);
    expect(logStore.events, hasLength(1));
    expect(state.counts[1], 1);
    expect(state.counts.containsKey(2), isFalse);
  });

  test('full run ends done with per-label counts and a session row',
      () async {
    final c = makeContainer(repsPerPrompt: 1);
    await c.read(dataCollectionControllerProvider.notifier).start();

    for (var wordId = 1; wordId <= 28; wordId++) {
      await emit(packet(wordId, 80));
    }

    final done = c.read(dataCollectionControllerProvider);
    expect(done.phase, CollectionPhase.done);
    expect(done.totalRecorded, 28);
    expect(logStore.events, hasLength(28));
    // Only the start command: telemetry streams continuously in the
    // firmware contract, so there is no stop command.
    expect(glove.commands, [AppCommand.setRate]);
    expect(logStore.sessionList.map((s) => s.sessionId),
        contains(done.sessionId));
  });

  test('abort stops mid-run; recorded rows stay (FR-10)', () async {
    final c = makeContainer();
    await c.read(dataCollectionControllerProvider.notifier).start();
    await emit(packet(1, 95));

    await c.read(dataCollectionControllerProvider.notifier).abort();
    expect(c.read(dataCollectionControllerProvider).phase,
        CollectionPhase.idle);
    expect(logStore.events, hasLength(1));
    expect(glove.commands, [AppCommand.setRate]);
  });
}
