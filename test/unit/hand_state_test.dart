import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/models/cal_info_packet.dart';
import 'package:talkhimik_app/domain/models/calibration_table.dart';
import 'package:talkhimik_app/domain/models/device_status.dart';
import 'package:talkhimik_app/domain/models/hand_state.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

void main() {
  test('packet loss % from received/lost counters', () {
    const s = HandState(hand: GloveHand.left, receivedFrames: 100, lostFrames: 2);
    expect(s.packetLossPercent, 2.0);
  });

  test('stale after 500 ms without a frame (master §6.1)', () {
    final at = DateTime.fromMillisecondsSinceEpoch(10000);
    final s = HandState(hand: GloveHand.left, lastFrameAt: at);
    expect(s.isStaleAt(at.add(const Duration(milliseconds: 499))), isFalse);
    expect(s.isStaleAt(at.add(const Duration(milliseconds: 501))), isTrue);
  });

  test('uncalibrated comes from STATUS flags bit0', () {
    expect(const HandState(hand: GloveHand.left).uncalibrated, isFalse);
    expect(
      const HandState(
        hand: GloveHand.left,
        status: DeviceStatusPacket(uncalibrated: true),
      ).uncalibrated,
      isTrue,
    );
  });

  test('calibration table maps masks and fields per finger', () {
    final packet = CalInfoPacket(
      validMask: 5, // bits: thumb + middle valid
      weakMask: 2, // bits: pointer span weak
      calibrationId: 3,
      flatOhm: const [10000, 0, 20000, 0, 0],
      bent90Ohm: const [30000, 0, 50000, 0, 0],
      flatAdc: const [500, 0, 600, 0, 0],
      bent90Adc: const [1500, 0, 1800, 0, 0],
      rDiv: const [10000, 10000, 10000, 10000, 10000],
      spanCounts: const [1000, 0, 1200, 0, 0],
      firmwareVersion: '1.2.0',
    );
    final table = CalibrationTable(packet);

    expect(table.calibrationId, 3);
    expect(table.firmwareVersion, '1.2.0');
    expect(table.fingers, hasLength(5));

    final thumb = table.finger(0);
    expect(thumb.name, 'thumb');
    expect(thumb.valid, isTrue);
    expect(thumb.weak, isFalse);
    expect(thumb.flatOhm, 10000);
    expect(thumb.bent90Ohm, 30000);

    final pointer = table.finger(1);
    expect(pointer.valid, isFalse);
    expect(pointer.weak, isTrue);

    final middle = table.finger(2);
    expect(middle.valid, isTrue);
    expect(middle.flatAdc, 600);
    expect(middle.bent90Adc, 1800);
    expect(middle.spanCounts, 1200);
  });
}
