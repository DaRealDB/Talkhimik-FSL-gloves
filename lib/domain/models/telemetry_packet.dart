import 'package:meta/meta.dart';

/// Which hand this glove is (TELEMETRY byte 0; firmware HAND constant).
enum GloveHand { left, right }

/// One decoded 29-byte TELEMETRY frame from the glove
/// (Code Reference §5.2, little-endian, every 50 ms).
///
/// This is the raw sensor stream: finger angles, raw ADC, IMU orientation,
/// and the calibration_id that produced them. It does NOT carry a recognized
/// word — the production label packet (GestureResultPacket) is a later
/// firmware stage; until then the transcript is driven by the mock glove.
@immutable
class TelemetryPacket {
  const TelemetryPacket({
    required this.hand,
    required this.seq,
    required this.angles,
    required this.rollDeg,
    required this.pitchDeg,
    required this.yawDeg,
    required this.rawAdc,
    required this.calibrationId,
    required this.quality,
    required this.receivedAt,
  });

  /// Glove hand, from the firmware HAND constant.
  final GloveHand hand;

  /// Wraps-around sequence number; gaps indicate dropped frames.
  final int seq;

  /// Flex angles 0–90°, order thumb, pointer, middle, ring, pinky.
  final List<int> angles;

  /// IMU orientation in degrees (wire format is ×10).
  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  /// Raw 12-bit ADC per finger, same order as [angles].
  final List<int> rawAdc;

  /// Calibration id of the profile that produced this frame
  /// (0 = never calibrated).
  final int calibrationId;

  /// Raw quality byte: bit0..4 = finger valid, bit5 = any weak span.
  final int quality;

  /// Phone clock at NOTIFY receipt (set by the connection implementation).
  final DateTime receivedAt;

  /// Per-finger validity mask from the quality byte.
  int get validMask => quality & 0x1F;

  /// True when any finger's span was under the 100-count warning threshold.
  bool get anyWeakSpan => quality & 0x20 != 0;
}
