import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/calibration_controller.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/core/strings/app_strings.dart';
import 'package:talkhimik_app/data/glove/glove_connection.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

import '../helpers/fake_glove_connection.dart';
import '../helpers/in_memory_calinfo_cache.dart';

CalInfoPacket calInfo(int id) => CalInfoPacket(
      validMask: 0x1F,
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

void main() {
  late FakeGloveConnection glove;
  late InMemoryCalInfoCache cache;

  ProviderContainer makeContainer() {
    glove = FakeGloveConnection();
    cache = InMemoryCalInfoCache();
    final container = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(glove),
        calInfoCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    container.read(calibrationControllerProvider);
    container.read(liveControllerProvider);
    return container;
  }

  Future<void> emitStatus(DeviceStatusPacket packet) async {
    glove.emitStatus(packet);
    await pumpEventQueue();
  }

  Future<void> emitCalInfo(CalInfoPacket packet) async {
    glove.emitCalInfo(packet);
    await pumpEventQueue();
  }

  DeviceStatusPacket status(int step, {int error = 0}) =>
      DeviceStatusPacket(mode: GloveMode.calibrating, calibrationStep: step,
          lastErrorCode: error);

  test('step → (finger, phase) mapping covers the 10-step wizard '
      '(master §4.2)', () async {
    final c = makeContainer();
    await c.read(calibrationControllerProvider.notifier).start(GloveHand.left);
    await emitStatus(status(1));
    var s = c.read(calibrationControllerProvider);
    expect(s.step, 1);
    expect(s.fingerIndex, 0);
    expect(s.isFlatStep, isTrue);

    for (var step = 1; step <= 10; step++) {
      await emitStatus(status(step));
      s = c.read(calibrationControllerProvider);
      expect(s.fingerIndex, (step - 1) ~/ 2, reason: 'step $step');
      expect(s.isFlatStep, step.isOdd, reason: 'step $step');
    }
  });

  test('capture sends the flat command on odd steps and 90° on even steps',
      () async {
    final c = makeContainer();
    final n = c.read(calibrationControllerProvider.notifier);
    await n.start(GloveHand.left);

    await emitStatus(status(1));
    await n.capture();
    expect(glove.commands, contains(AppCommand.captureFlat));

    await emitStatus(status(2));
    await n.capture();
    expect(glove.commands, contains(AppCommand.capture90));
  });

  test('error 3 keeps the step with the redo message; error 4 advances '
      'and marks the finger (master §4.3)', () async {
    final c = makeContainer();
    await c.read(calibrationControllerProvider.notifier).start(GloveHand.left);

    await emitStatus(status(2, error: 3));
    var s = c.read(calibrationControllerProvider);
    expect(s.step, 2);
    expect(s.error, AppStrings.calibrationSpanReject);

    await emitStatus(status(3, error: 4));
    s = c.read(calibrationControllerProvider);
    expect(s.step, 3); // firmware advances on error 4
    expect(s.faultedFinger, 1); // pointer
    expect(s.error, AppStrings.calibrationWiringWarning);
  });

  test('completion is detected by the calibration_id increase on mode 0 '
      '(master §4.2)', () async {
    final c = makeContainer();
    // A previously calibrated glove: id 3.
    await emitCalInfo(calInfo(3));
    final n = c.read(calibrationControllerProvider.notifier);
    await n.start(GloveHand.left);
    expect(c.read(calibrationControllerProvider).startCalibrationId, 3);

    await emitStatus(status(1));
    // Firmware saves at step 10 → CAL_INFO notify with the new id.
    await emitCalInfo(calInfo(4));
    await emitStatus(const DeviceStatusPacket(
        mode: GloveMode.streaming, calibrationStep: 0));

    final s = c.read(calibrationControllerProvider);
    expect(s.phase, CalibrationPhase.done);
    expect(cache.saved[GloveHand.left]?.calibrationId, 4); // mirrored
  });

  test('mode returning to 0 without an id increase ends idle (no phantom '
      'completion)', () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3));
    await c.read(calibrationControllerProvider.notifier).start(GloveHand.left);
    await emitStatus(status(1));
    await emitStatus(const DeviceStatusPacket(
        mode: GloveMode.streaming, calibrationStep: 0));

    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.idle);
  });

  test('uncalibrated start (id 0) completes on the first saved profile',
      () async {
    final c = makeContainer();
    final n = c.read(calibrationControllerProvider.notifier);
    await n.start(GloveHand.left);
    expect(c.read(calibrationControllerProvider).startCalibrationId, 0);

    await emitCalInfo(calInfo(1));
    await emitStatus(const DeviceStatusPacket(
        mode: GloveMode.streaming, calibrationStep: 0));

    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.done);
  });

  test('cancel sends 0x04 and keeps the prior profile (id unchanged)',
      () async {
    final c = makeContainer();
    await emitCalInfo(calInfo(3));
    await c.read(calibrationControllerProvider.notifier).start(GloveHand.left);
    await emitStatus(status(2));

    await c.read(calibrationControllerProvider.notifier).cancel();
    expect(glove.commands, contains(AppCommand.cancelCalibration));
    expect(c.read(calibrationControllerProvider).phase,
        CalibrationPhase.idle);
    expect(cache.saved[GloveHand.left]?.calibrationId, 3);
  });
}
