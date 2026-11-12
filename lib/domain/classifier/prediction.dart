import 'package:meta/meta.dart';

/// One classifier output for a [HandFrame] (before stabilization).
@immutable
class Prediction {
  const Prediction({
    required this.label,
    required this.confidence,
    required this.source,
    this.className,
    this.top3 = const [],
  });

  /// Representative vocabulary letter (e.g. 'A', 'D', '_rest' for C4).
  final String label;

  /// 0–1. The stand-in caps at
  /// [RecognitionConstants.thresholdConfidenceCap]; the trained model uses
  /// its softmax probability (uncapped — FR-4 thresholds apply as-is).
  final double confidence;

  /// Provenance: 'phone-threshold' (C1) or 'phone-tflite' (C4).
  final String source;

  /// Human-readable rule/class name for the debug panel ('FIST', 'D-G-L',
  /// …). Null when the classifier has no named class.
  final String? className;

  /// Top-3 labels in confidence order for the debug panel (C4 model
  /// fills this; the stand-in leaves it empty).
  final List<String> top3;
}
