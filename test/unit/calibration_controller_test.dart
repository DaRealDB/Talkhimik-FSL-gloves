import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/calibration_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calibration_store.dart';
import '../helpers/in_memory_settings_service.dart';

void main() {
  late FakeGloveConnection glove;
  late InMemoryCalibrationProfileStore store;
  late InMemorySettingsService settings;

  ProviderContainer makeContainer({int repsPerPrompt = 3}) {
    glove = FakeGloveConnection();
    store = InMemoryCalibrationProfileStore();
    settings = InMemorySettingsService()..participant = 'P-001';
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(glove),
        settingsServiceProvider.overrideWithValue(settings),
        calibrationProfileStoreProvider.overrideWithValue(store),
        calibrationControllerProvider
            .overrideWith(() => CalibrationController(
                repsPerPrompt: repsPerPrompt)),
      ],
    );
    addTearDown(container.dispose);
    container.read(calibrationControllerProvider);
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

  test('gates on a missing participant id (FR-13)', () async {
    final c = makeContainer();
    settings.participant = '';
    await c.read(calibrationControllerProvider.notifier).start();
    expect(c.read(calibrationControllerProvider).error,
        AppStrings.calibrationNeedsParticipant);
    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.idle);
    expect(glove.commands, isEmpty);
  });

  test('full run captures reps, computes stats, and saves the profile',
      () async {
    final c = makeContainer(repsPerPrompt: 2);
    await c.read(calibrationControllerProvider.notifier).start();

    final state = c.read(calibrationControllerProvider);
    expect(state.phase, CalibrationPhase.prompting);
    expect(state.prompts.length, 28);
    expect(state.currentPrompt?.wordId, 1);
    expect(glove.commands, contains(AppCommand.calibrate));

    // Two reps per word across the whole alphabet; give word 1 the values
    // 90/94 so its aggregate is deterministic.
    for (var wordId = 1; wordId <= 28; wordId++) {
      for (var rep = 0; rep < 2; rep++) {
        final conf = wordId == 1 ? [90, 94][rep] : 80 + rep;
        await emit(packet(wordId, conf));
      }
    }

    final done = c.read(calibrationControllerProvider);
    expect(done.phase, CalibrationPhase.done);
    expect(done.profile, isNotNull);
    expect(done.profile!.participantId, 'P-001');
    expect(done.profile!.stats.length, 28);
    final first = done.profile!.stats
        .firstWhere((s) => s.wordId == 1);
    expect(first.sampleCount, 2);
    expect(first.meanConfidence, 92);
    expect(first.minConfidence, 90);
    expect(first.maxConfidence, 94);
    expect(store.saved, same(done.profile));
    expect(glove.commands, contains(AppCommand.stopStream));
  });

  test('samples outside a run are ignored', () async {
    final c = makeContainer();
    await emit(packet(1, 95));
    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.idle);
    expect(store.saved, isNull);
  });

  test('abort stops mid-run and saves nothing', () async {
    final c = makeContainer();
    await c.read(calibrationControllerProvider.notifier).start();
    await emit(packet(1, 90));

    await c.read(calibrationControllerProvider.notifier).abort();
    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.idle);
    expect(store.saved, isNull);
    expect(glove.commands, contains(AppCommand.stopStream));

    // Prompts restart from the top on the next run.
    await c.read(calibrationControllerProvider.notifier).start();
    expect(
        c.read(calibrationControllerProvider).currentPrompt?.wordId, 1);
  });
}
