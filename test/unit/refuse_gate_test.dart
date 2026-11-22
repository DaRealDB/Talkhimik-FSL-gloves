import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/classifier/hand_frame.dart';
import 'package:talkhimik_app/domain/classifier/refuse_gate.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

HandFrame frame({
  List<double> angles = const [50, 70, 70, 70, 70],
  int calibrationId = 3,
  bool uncalibrated = false,
  int validMask = 0x1F,
  DateTime? at,
}) =>
    HandFrame(
      hand: GloveHand.left,
      angles: angles,
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      validMask: validMask,
      calibrationId: calibrationId,
      uncalibratedFlag: uncalibrated,
      timestamp: at ?? DateTime.now(),
    );

void main() {
  test('a gate-clean calibrated frame passes', () {
    expect(RefuseGate.evaluate(frame()), GateReason.none);
  });

  test('never calibrated (cal_id 0) refuses as uncalibrated', () {
    expect(RefuseGate.evaluate(frame(calibrationId: 0)),
        GateReason.uncalibrated);
  });

  test('STATUS uncalibrated flag refuses as uncalibrated', () {
    expect(RefuseGate.evaluate(frame(uncalibrated: true)),
        GateReason.uncalibrated);
  });

  test('a frame older than 500 ms refuses as stale', () {
    final at =
        DateTime.now().subtract(const Duration(milliseconds: 501));
    expect(RefuseGate.evaluate(frame(at: at)), GateReason.stale);
  });

  test('a frame exactly at the freshness edge is not stale', () {
    final now = DateTime.now();
    final at = now.subtract(const Duration(milliseconds: 500));
    expect(RefuseGate.evaluate(frame(at: at), now: now), GateReason.none);
  });

  test('an invalid finger (missing quality bit) refuses as invalidFinger',
      () {
    // Bit 4 (pinky) missing — all five feed the rules.
    expect(RefuseGate.evaluate(frame(validMask: 0x0F)),
        GateReason.invalidFinger);
  });

  test('cal_id 0 wins over the stale check (documented priority)', () {
    final at = DateTime.now().subtract(const Duration(seconds: 2));
    expect(
      RefuseGate.evaluate(frame(calibrationId: 0, at: at)),
      GateReason.uncalibrated,
    );
  });
}
