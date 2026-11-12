import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/gesture_result.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/fake_tts_service.dart';
import '../helpers/in_memory_calinfo_cache.dart';
import '../helpers/in_memory_log_store.dart';
import '../helpers/in_memory_settings_service.dart';

/// A gate-clean 'A' (FIST) frame: thumb 50, others 70, all fingers valid,
/// cal_id 3, calibrated.
TelemetryPacket fistFrame(int seq,
        {GloveHand hand = GloveHand.left, DateTime? at}) =>
    TelemetryPacket(
      hand: hand,
      seq: seq,
      angles: const [50, 70, 70, 70, 70],
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      rawAdc: const [100, 200, 300, 400, 500],
      calibrationId: 3,
      quality: 0x1F,
      receivedAt: at ?? DateTime.now(),
    );

void main() {
  (ProviderContainer, FakeGloveConnection, FakeGloveConnection, InMemorySettingsService,
      InMemoryLogStore, FakeTtsService) makeContainer({bool mock = false}) {
    final left = FakeGloveConnection();
    final right = FakeGloveConnection();
    final settings = InMemorySettingsService();
    final logs = InMemoryLogStore();
    final tts = FakeTtsService();
    final c = ProviderContainer(overrides: [
      gloveConnectionProvider.overrideWithValue(left),
      rightGloveConnectionProvider.overrideWithValue(right),
      gloveIsMockProvider.overrideWithValue(mock),
      settingsServiceProvider.overrideWithValue(settings),
      logStoreProvider.overrideWithValue(logs),
      ttsServiceProvider.overrideWithValue(tts),
      calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
    ]);
    addTearDown(c.dispose);
    c.read(liveControllerProvider);
    c.read(recognitionControllerProvider);
    return (c, left, right, settings, logs, tts);
  }

  Future<void> pump(ProviderContainer c) async {
    await pumpEventQueue();
    await pumpEventQueue();
  }

  test('a held FIST emits one transcript event: correct word_id, '
      'vote-shared confidence, phone source, and model version', () async {
    final (c, left, _, _, logs, tts) = makeContainer();
    c.read(transcriptControllerProvider);
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    for (var i = 0; i < 25; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }

    final transcript = c.read(transcriptControllerProvider);
    expect(transcript.entries.length, 1);
    final entry = transcript.entries.first;
    expect(entry.wordId, 1); // 'A'
    expect(entry.filipino, 'A');
    expect(entry.source, 'phone-threshold');
    // vote share 10/20 x 0.55 cap = 0.275 -> 28%.
    expect(entry.confidence, 28);
    expect(tts.spoken, contains('A'));

    final logEntries = await logs.eventsForSession(transcript.sessionId);
    expect(logEntries.length, 1);
    expect(logEntries.first.source, 'phone-threshold');
    expect(logEntries.first.modelVersion, 'stand-in-v1');
    expect(logEntries.first.wordId, 1);
  });

  test('recognizer is OFF in mock mode: no events reach the transcript '
      'from the phone path', () async {
    final (c, left, _, _, _, _) = makeContainer(mock: true);
    c.read(transcriptControllerProvider);
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    for (var i = 0; i < 25; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }

    expect(c.read(recognitionControllerProvider).enabled, isFalse);
    expect(c.read(transcriptControllerProvider).entries, isEmpty);
  });

  test('a real glove label packet pauses phone recognition', () async {
    final (c, left, _, _, _, _) = makeContainer();
    c.read(transcriptControllerProvider);
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    for (var i = 0; i < 25; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }
    expect(c.read(recognitionControllerProvider).enabled, isTrue);

    // A glove label packet arrives: the recognizer stands down and no
    // further phone events flow, but the glove packet itself still feeds
    // the transcript via the normal path.
    left.emitGesture(GestureResultPacket(
      wordId: 2,
      confidence: 90,
      gloveTimestampMs: DateTime.now().millisecondsSinceEpoch,
      receivedAt: DateTime.now(),
    ));
    await pump(c);
    expect(c.read(recognitionControllerProvider).pausedForLabelPackets, isTrue);

    for (var i = 30; i < 50; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }
    // The phone emitted 'A' before the pause; after it, only the glove
    // packet's entry exists — the extra frames added nothing.
    final transcript = c.read(transcriptControllerProvider);
    expect(transcript.entries.length, 2);
    expect(transcript.entries.last.wordId, 2);
  });

  test('uncalibrated gloves are refused with the right gate reason and '
      'never guess', () async {
    final (c, left, _, _, _, _) = makeContainer();
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: true));
    for (var i = 0; i < 25; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }

    final recog = c.read(recognitionControllerProvider);
    expect(recog.blockedReason, 'uncalibrated');
    expect(recog.lastEmittedLabel, isNull);
  });

  test('a stale frame resets and blocks with the stale reason', () async {
    final (c, left, _, _, _, _) = makeContainer();
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    left.emitTelemetry(fistFrame(0,
        at: DateTime.now().subtract(const Duration(seconds: 1))));
    await pump(c);

    expect(c.read(recognitionControllerProvider).blockedReason, 'stale');
  });

  test('a frame with an invalid finger blocks with the invalid-finger '
      'reason', () async {
    final (c, left, _, _, _, _) = makeContainer();
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    left.emitTelemetry(TelemetryPacket(
      hand: GloveHand.left,
      seq: 0,
      angles: const [50, 70, 70, 70, 70],
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      rawAdc: const [100, 200, 300, 400, 500],
      calibrationId: 3,
      quality: 0x0F, // pinky bit missing
      receivedAt: DateTime.now(),
    ));
    await pump(c);

    expect(
        c.read(recognitionControllerProvider).blockedReason, 'invalid finger');
  });

  test('signing hand Auto reads the only connected glove', () async {
    final (c, left, right, settings, _, _) = makeContainer();
    await pump(c);

    right.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    for (var i = 0; i < 10; i++) {
      right.emitTelemetry(fistFrame(i, hand: GloveHand.right));
      await pump(c);
    }
    expect(c.read(recognitionControllerProvider).activeHand,
        GloveHand.right);
  });

  test('signing hand Auto prefers Right when both gloves are live', () async {
    final (c, left, right, _, _, _) = makeContainer();
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    right.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    left.emitTelemetry(fistFrame(0));
    right.emitTelemetry(fistFrame(0, hand: GloveHand.right));
    await pump(c);

    expect(
        c.read(recognitionControllerProvider).activeHand, GloveHand.right);
  });

  test('signing hand Left forces the left glove even when only the right '
      'is connected', () async {
    final (c, left, right, settings, _, _) = makeContainer();
    await pump(c);
    await c.read(settingsControllerProvider.notifier).setSigningHand('left');
    await pump(c);

    right.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    right.emitTelemetry(fistFrame(0, hand: GloveHand.right));
    await pump(c);

    // Left is chosen, but has no frames — nothing to classify, no guess.
    expect(c.read(recognitionControllerProvider).activeHand, GloveHand.left);
    expect(c.read(recognitionControllerProvider).lastEmittedLabel, isNull);
  });

  test('the Developer toggle off stops recognition entirely', () async {
    final (c, left, _, _, _, _) = makeContainer();
    await pump(c);
    await c
        .read(settingsControllerProvider.notifier)
        .setPhoneRecognitionEnabled(false);
    await pump(c);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: false));
    for (var i = 0; i < 25; i++) {
      left.emitTelemetry(fistFrame(i));
      await pump(c);
    }

    expect(c.read(recognitionControllerProvider).enabled, isFalse);
  });
}
