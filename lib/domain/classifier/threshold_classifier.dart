import 'gesture_classifier.dart';
import 'hand_frame.dart';
import 'prediction.dart';
import 'recognition_constants.dart';

/// Per-finger angle bound: [min] inclusive, [max] exclusive.
/// [double.negativeInfinity] / [double.infinity] leave a side unbounded.
class FingerBounds {
  const FingerBounds(this.min, this.max);

  final double min;
  final double max;

  bool contains(double angle) => angle >= min && angle < max;
}

const double _none = double.negativeInfinity;
const double _all = double.infinity;

/// One editable rule row of the stand-in classifier.
///
/// Each class merges the FSL letters that are indistinguishable from
/// angles alone, and maps to ONE representative letter (the label) —
/// concept C5: "Unrecognized beats wrong", so a merged class must never
/// be presented as certain (see [ThresholdClassifier]).
class ThresholdRule {
  const ThresholdRule({
    required this.className,
    required this.label,
    required this.thumb,
    required this.pointer,
    required this.middle,
    required this.ring,
    required this.pinky,
  });

  /// Debug-panel name of the merged class ('FIST', 'D-G-L', …).
  final String className;

  /// Representative letter emitted when this class wins.
  final String label;

  final FingerBounds thumb;
  final FingerBounds pointer;
  final FingerBounds middle;
  final FingerBounds ring;
  final FingerBounds pinky;

  bool matches(List<double> angles) =>
      thumb.contains(angles[0]) &&
      pointer.contains(angles[1]) &&
      middle.contains(angles[2]) &&
      ring.contains(angles[3]) &&
      pinky.contains(angles[4]);
}

/// THE rule table — one const list, editable, first match in table order
/// wins (only boundary frames overlap; the order below follows the
/// dashboard's ten classes).
///
/// Angles are 0–90°, order thumb/pointer/middle/ring/pinky.
/// Bounds are min-inclusive, max-exclusive, so "<25" is max 25 and
/// "within 25–65" is min 25, max 66.
const List<ThresholdRule> thresholdRules = [
  ThresholdRule(
    className: 'FIST', label: 'A',
    thumb: FingerBounds(45, _all),
    pointer: FingerBounds(65, _all), middle: FingerBounds(65, _all),
    ring: FingerBounds(65, _all), pinky: FingerBounds(65, _all),
  ),
  ThresholdRule(
    className: 'B', label: 'B',
    thumb: FingerBounds(65, _all),
    pointer: FingerBounds(_none, 25), middle: FingerBounds(_none, 25),
    ring: FingerBounds(_none, 25), pinky: FingerBounds(_none, 25),
  ),
  ThresholdRule(
    className: 'F', label: 'F',
    thumb: FingerBounds(_none, 45),
    pointer: FingerBounds(_none, 25), middle: FingerBounds(_none, 25),
    ring: FingerBounds(_none, 25), pinky: FingerBounds(_none, 25),
  ),
  ThresholdRule(
    className: 'D-G-L', label: 'D',
    thumb: FingerBounds(45, _all),
    pointer: FingerBounds(_none, 25),
    middle: FingerBounds(65, _all), ring: FingerBounds(65, _all),
    pinky: FingerBounds(65, _all),
  ),
  ThresholdRule(
    className: 'V', label: 'V',
    thumb: FingerBounds(65, _all),
    pointer: FingerBounds(_none, 25), middle: FingerBounds(_none, 25),
    ring: FingerBounds(65, _all), pinky: FingerBounds(65, _all),
  ),
  ThresholdRule(
    className: 'U-K-P', label: 'U',
    thumb: FingerBounds(_none, 45),
    pointer: FingerBounds(_none, 25), middle: FingerBounds(_none, 25),
    ring: FingerBounds(65, _all), pinky: FingerBounds(65, _all),
  ),
  ThresholdRule(
    className: 'W', label: 'W',
    thumb: FingerBounds(_none, 65),
    pointer: FingerBounds(_none, 25), middle: FingerBounds(_none, 25),
    ring: FingerBounds(_none, 25), pinky: FingerBounds(45, _all),
  ),
  ThresholdRule(
    className: 'I', label: 'I',
    thumb: FingerBounds(65, _all),
    pointer: FingerBounds(65, _all), middle: FingerBounds(65, _all),
    ring: FingerBounds(65, _all), pinky: FingerBounds(_none, 25),
  ),
  ThresholdRule(
    className: 'Y', label: 'Y',
    thumb: FingerBounds(_none, 25),
    pointer: FingerBounds(65, _all), middle: FingerBounds(65, _all),
    ring: FingerBounds(65, _all), pinky: FingerBounds(_none, 25),
  ),
  ThresholdRule(
    className: 'C', label: 'C',
    thumb: FingerBounds(25, 66),
    pointer: FingerBounds(25, 66), middle: FingerBounds(25, 66),
    ring: FingerBounds(25, 66), pinky: FingerBounds(25, 66),
  ),
];

/// Stand-in rule-based classifier (C1). Replaced by the trained model in
/// C4 via [ClassifierFactory] — never presented as certain: every output
/// carries the merged-class confidence cap.
class ThresholdClassifier implements GestureClassifier {
  const ThresholdClassifier();

  @override
  String get source => RecognitionConstants.thresholdSource;

  @override
  String get modelVersion => RecognitionConstants.thresholdModelVersion;

  /// The stand-in has no REST class and no trained floor — its cap is the
  /// merged-class ceiling instead.
  @override
  String? get restLabel => null;

  @override
  double? get confidenceFloor => null;

  @override
  Prediction? classifyFrame(HandFrame frame) {
    for (final rule in thresholdRules) {
      if (rule.matches(frame.angles)) {
        return Prediction(
          label: rule.label,
          confidence: RecognitionConstants.thresholdConfidenceCap,
          source: source,
          className: rule.className,
        );
      }
    }
    return null;
  }
}
