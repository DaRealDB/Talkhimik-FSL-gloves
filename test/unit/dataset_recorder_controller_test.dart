import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/dataset_recorder_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';
import '../helpers/in_memory_settings_service.dart';

CalInfoPacket calInfo(int id, {int validMask = 0x1F}) => CalInfoPacket(
      validMask: validMask,
      weakMask: 0,
      calibrationId: id,
      flatOhm: const [10000, 10000, 10000, 10000, 10000],
      bent90Ohm: const [30000, 30000, 30000, 30000, 30000],
      flatAdc: const [500, 500, 500, 500, 500],
      bent90Adc: const [1500, 1500, 1500, 1500, 1500],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [1000, 1000, 1000, 1000, 1000],
      firmwareVersion: '1.2.0',
    );

TelemetryPacket frame(int seq, int calId,
        {List<int>? raw, DateTime? at}) =>
    TelemetryPacket(
      hand: GloveHand.left,
      seq: seq,
      angles: const [10, 20, 30, 40, 50],
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      rawAdc: raw ?? const [100, 200, 300, 400, 500],
      calibrationId: calId,
      quality: 0x1F,
      receivedAt: at ?? DateTime.now(),
    );

void main() {
  late FakeGloveConnection left;
  late FakeGloveConnection right;
  late InMemorySettingsService settings;
  late Directory dir;

  ProviderContainer makeContainer() {
    left = FakeGloveConnection();
    right = FakeGloveConnection();
    settings = InMemorySettingsService()
      ..participant = 'P-001'
      ..consent = true;
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(left),
        rightGloveConnectionProvider.overrideWithValue(right),
        settingsServiceProvider.overrideWithValue(settings),
        calInfoCacheProvider.overrideWithValue(InMemoryCalInfoCache()),
        datasetDirectoryProvider.overrideWithValue(Future.value(dir)),
        // Long sampler interval: tests drive sampleNow() directly.
        datasetRecorderControllerProvider.overrideWith(
            () => DatasetRecorderController(const Duration(hours: 1))),
      ],
    );
    addTearDown(container.dispose);
    container.read(datasetRecorderControllerProvider);
    container.read(liveControllerProvider);
    return container;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('talkhimik_rec_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> emit(TelemetryPacket packet) async {
    left.emitTelemetry(packet);
    await pumpEventQueue();
  }

  Future<void> emitCalInfo(CalInfoPacket packet) async {
    left.emitCalInfo(packet);
    await pumpEventQueue();
  }

  Future<void> startRecording(ProviderContainer c) async {
    await c.read(datasetRecorderControllerProvider.notifier).start();
  }

  test('consent gate blocks recording (NFR-8, master §5.1)', () async {
    final c = makeContainer();
    settings.consent = false;
    await startRecording(c);
    expect(c.read(datasetRecorderControllerProvider).error,
        AppStrings.recordNeedsConsent);
    expect(c.read(datasetRecorderControllerProvider).phase,
        RecordingPhase.idle);
  });

  test('a connected uncalibrated glove (cal_id 0) blocks recording',
      () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(0));
    await emit(frame(1, 0));
    await startRecording(c);
    expect(c.read(datasetRecorderControllerProvider).error,
        AppStrings.recordNeedsCalibration);
  });

  test('seq gap 4 drops, gap 3 keeps; take_id increments per start press '
      '(master §5.1)', () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3));
    await startRecording(c);
    await c
        .read(datasetRecorderControllerProvider.notifier)
        .startTake('A');
    final recorder = c.read(datasetRecorderControllerProvider.notifier);

    await emit(frame(10, 3));
    await recorder.sampleNow();
    await emit(frame(14, 3)); // gap 3 → kept
    await recorder.sampleNow();
    await emit(frame(19, 3)); // gap 4 → dropped
    await recorder.sampleNow();

    var s = c.read(datasetRecorderControllerProvider);
    expect(s.active[GloveHand.left]!.rows, 2);
    expect(s.active[GloveHand.left]!.seqGapDrops, 1);
    expect(s.active[GloveHand.left]!.droppedFrames, 1);
    expect(s.active[GloveHand.left]!.takeId, 1);

    // Second take: take_id increments within the session.
    await c
        .read(datasetRecorderControllerProvider.notifier)
        .startTake('B');
    await emit(frame(20, 3));
    await recorder.sampleNow();
    s = c.read(datasetRecorderControllerProvider);
    expect(s.active[GloveHand.left]!.takeId, 2);
    expect(s.active[GloveHand.left]!.rows, 3);
  });

  test('ADC rail (raw 0 or 4095) drops only on VALID fingers', () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3, validMask: 0x1E)); // thumb invalid
    await startRecording(c);
    await c
        .read(datasetRecorderControllerProvider.notifier)
        .startTake('A');
    final recorder = c.read(datasetRecorderControllerProvider.notifier);

    // Thumb (invalid) railed — not a drop; pointer (valid) railed — drop.
    await emit(frame(10, 3, raw: [0, 200, 300, 400, 500]));
    await recorder.sampleNow();
    await emit(frame(11, 3, raw: [0, 4095, 300, 400, 500]));
    await recorder.sampleNow();

    final s = c.read(datasetRecorderControllerProvider);
    expect(s.active[GloveHand.left]!.rows, 1);
    expect(s.active[GloveHand.left]!.adcRail, 1);
  });

  test('a calibration change closes the session and opens a new file '
      '(master §5.1)', () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3));
    await startRecording(c);
    final recorder = c.read(datasetRecorderControllerProvider.notifier);
    await recorder.startTake('A');

    await emit(frame(10, 3));
    await recorder.sampleNow();
    await emitCalInfo(calInfo(4));
    await emit(frame(11, 4)); // new calibration on the wire
    await recorder.sampleNow();
    await recorder.stop();

    final sessions = c.read(datasetRecorderControllerProvider).sessions;
    // Both finalized files exist: the closed cal-3 session and the cal-4
    // session closed by stop(). Newest first.
    expect(sessions, hasLength(2));
    expect(sessions.first.calibrationId, 4);
    expect(sessions.last.calibrationId, 3);
    expect(sessions.last.rows, 1);
  });

  test('rows are only written while a take is active', () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3));
    await startRecording(c);
    final recorder = c.read(datasetRecorderControllerProvider.notifier);

    await emit(frame(10, 3));
    await recorder.sampleNow(); // no take yet → session opens, no row
    final opened = c.read(datasetRecorderControllerProvider).active;
    expect(opened[GloveHand.left]!.rows, 0);

    await recorder.startTake('A');
    await emit(frame(11, 3));
    await recorder.sampleNow();
    expect(
        c.read(datasetRecorderControllerProvider).active[GloveHand.left]!.rows,
        1);

    await recorder.stopTake();
    await emit(frame(12, 3));
    await recorder.sampleNow();
    expect(
        c.read(datasetRecorderControllerProvider).active[GloveHand.left]!.rows,
        1);
  });

  test('an empty take label is blocked', () async {
    final c = makeContainer();
    await c
        .read(datasetRecorderControllerProvider.notifier)
        .startTake('   ');
    expect(c.read(datasetRecorderControllerProvider).error,
        AppStrings.recordNeedsLabel);
  });
}
