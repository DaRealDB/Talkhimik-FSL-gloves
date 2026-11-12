import 'hand_frame.dart';

/// Why the gate refused to classify a frame (debug panel + tests).
enum GateReason {
  /// Frame passes every check — classification may proceed.
  none,

  /// Never calibrated (cal_id 0) or the glove is using placeholder angles.
  uncalibrated,

  /// No fresh frame within [RecognitionConstants.staleFrameMs].
  stale,

  /// A finger the rules need is marked invalid in the quality byte.
  invalidFinger,
}

/// Shared refusal checks for every classifier (concept C5: refuse, never
/// guess). The RecognitionController runs this before classifying; the
/// trained-model path (C4) reuses the same gate.
class RefuseGate {
  RefuseGate._();

  static GateReason evaluate(HandFrame frame, {DateTime? now}) {
    final at = now ?? DateTime.now();
    if (frame.uncalibratedFlag || frame.calibrationId == 0) {
      return GateReason.uncalibrated;
    }
    if (frame.isStaleAt(at)) return GateReason.stale;
    // All five fingers feed the C1 rules and the C4 model input.
    if (frame.validMask & 0x1F != 0x1F) return GateReason.invalidFinger;
    return GateReason.none;
  }
}
