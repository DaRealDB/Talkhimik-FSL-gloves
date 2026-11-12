import 'hand_frame.dart';
import 'prediction.dart';

/// Pure classification contract: one frame in, at most one label out.
///
/// Classifiers NEVER guess — null means "not recognized" and must feed the
/// stabilizer as a neutral frame. Gate concerns (calibration, freshness,
/// finger validity) live in [RefuseGate] and are applied by the
/// RecognitionController before this is called, so implementations assume
/// a gate-clean frame.
///
/// The metadata getters exist so the controller can apply the trained
/// model's confidence floor and REST semantics uniformly (C4) and so the
/// debug panel can show what is actually running.
abstract interface class GestureClassifier {
  Prediction? classifyFrame(HandFrame frame);

  /// Provenance: 'phone-threshold' (C1) or 'phone-tflite' (C4).
  String get source;

  /// Model version for the Hive log/export; the stand-in reports its own
  /// constant, the trained model derives from labels.json.
  String get modelVersion;

  /// Trained model's REST class ('_rest'); null for the stand-in.
  String? get restLabel;

  /// Trained model's confidence floor (labels.json); below it nothing is
  /// emitted. Null for the stand-in (its own cap applies instead).
  double? get confidenceFloor;
}
