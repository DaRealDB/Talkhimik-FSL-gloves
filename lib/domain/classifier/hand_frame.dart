import 'package:meta/meta.dart';

import '../models/telemetry_packet.dart';
import 'recognition_constants.dart';

/// One normalized sensor snapshot fed to a [GestureClassifier].
///
/// Built from a [TelemetryPacket] plus the glove's calibration state; the
/// classifier layer itself never touches BLE packets or STATUS flags.
@immutable
class HandFrame {
  const HandFrame({
    required this.hand,
    required this.angles,
    required this.rollDeg,
    required this.pitchDeg,
    required this.yawDeg,
    required this.validMask,
    required this.calibrationId,
    required this.uncalibratedFlag,
    required this.timestamp,
  });

  factory HandFrame.fromTelemetry(
    TelemetryPacket t, {
    required bool uncalibrated,
  }) =>
      HandFrame(
        hand: t.hand,
        angles: [for (final a in t.angles) a.toDouble()],
        rollDeg: t.rollDeg,
        pitchDeg: t.pitchDeg,
        yawDeg: t.yawDeg,
        validMask: t.validMask,
        calibrationId: t.calibrationId,
        uncalibratedFlag: uncalibrated,
        timestamp: t.receivedAt,
      );

  final GloveHand hand;

  /// Flex angles 0–90°, order thumb, pointer, middle, ring, pinky.
  final List<double> angles;

  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  /// Quality byte bits 0..4 (finger valid).
  final int validMask;

  /// Calibration id that produced this frame (0 = never calibrated).
  final int calibrationId;

  /// STATUS flags bit0 — placeholder angles in use.
  final bool uncalibratedFlag;

  /// Phone clock at NOTIFY receipt.
  final DateTime timestamp;

  /// Freshness per §6.1: no frame within the last 500 ms counts as stale.
  bool isStaleAt(DateTime now) =>
      now.difference(timestamp) >
      const Duration(milliseconds: RecognitionConstants.staleFrameMs);
}
