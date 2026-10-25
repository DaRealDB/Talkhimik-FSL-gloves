import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/application/providers.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

import '../helpers/fake_glove_connection.dart';

TelemetryPacket frame(int seq,
        {GloveHand hand = GloveHand.left, required DateTime at}) =>
    TelemetryPacket(
      hand: hand,
      seq: seq,
      angles: const [10, 20, 30, 40, 50],
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      rawAdc: const [100, 200, 300, 400, 500],
      calibrationId: 3,
      quality: 0x1F,
      receivedAt: at,
    );

void main() {
  test('telemetry folds into the correct hand with loss and rate counters',
      () async {
    final left = FakeGloveConnection();
    final right = FakeGloveConnection();
    final c = ProviderContainer(
      overrides: [
        gloveConnectionProvider.overrideWithValue(left),
        rightGloveConnectionProvider.overrideWithValue(right),
      ],
    );
    addTearDown(c.dispose);
    c.read(liveControllerProvider);

    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    left.emitTelemetry(frame(10, at: t0));
    await pumpEventQueue();
    var s = c.read(liveControllerProvider);
    expect(s.left.receivedFrames, 1);
    expect(s.left.telemetry?.seq, 10);
    expect(s.left.updateRateHz, 1);
    expect(s.right.receivedFrames, 0); // right untouched

    // Gap 14 − 10 − 1 = 3 lost frames (wrap-safe, master §5.1).
    left.emitTelemetry(frame(14, at: t0.add(const Duration(milliseconds: 200))));
    await pumpEventQueue();
    s = c.read(liveControllerProvider);
    expect(s.left.lostFrames, 3);
    expect(s.left.receivedFrames, 2);

    // Trailing-second window evicts only frames older than 1 s.
    left.emitTelemetry(frame(15, at: t0.add(const Duration(milliseconds: 1100))));
    await pumpEventQueue();
    s = c.read(liveControllerProvider);
    expect(s.left.updateRateHz, 2); // t0 evicted; t0+200ms and t0+1100ms remain
  });

  test('a telemetry hand byte disagreeing with the glove name sets the '
      'mismatch flag but keeps the data (master §7.3)', () async {
    final left = FakeGloveConnection();
    final c = ProviderContainer(
      overrides: [gloveConnectionProvider.overrideWithValue(left)],
    );
    addTearDown(c.dispose);
    c.read(liveControllerProvider);

    left.emitTelemetry(
        frame(1, hand: GloveHand.right, at: DateTime.now()));
    await pumpEventQueue();

    final s = c.read(liveControllerProvider);
    expect(s.left.telemetry, isNotNull); // data trusted
    expect(s.left.handMismatch, isTrue);
  });

  test('status and CAL_INFO fold into the hand state', () async {
    final left = FakeGloveConnection();
    final c = ProviderContainer(
      overrides: [gloveConnectionProvider.overrideWithValue(left)],
    );
    addTearDown(c.dispose);
    c.read(liveControllerProvider);

    left.emitStatus(const DeviceStatusPacket(uncalibrated: true));
    await pumpEventQueue();
    expect(c.read(liveControllerProvider).left.uncalibrated, isTrue);

    left.emitCalInfo(CalInfoPacket(
      validMask: 0x1F,
      weakMask: 0,
      calibrationId: 7,
      flatOhm: const [10000, 10000, 10000, 10000, 10000],
      bent90Ohm: const [30000, 30000, 30000, 30000, 30000],
      flatAdc: const [500, 500, 500, 500, 500],
      bent90Adc: const [1500, 1500, 1500, 1500, 1500],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [1000, 1000, 1000, 1000, 1000],
      firmwareVersion: '1.2.0',
    ));
    await pumpEventQueue();
    expect(c.read(liveControllerProvider).left.calInfo?.calibrationId, 7);
  });
}
