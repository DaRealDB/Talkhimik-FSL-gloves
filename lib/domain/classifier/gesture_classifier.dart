import 'hand_frame.dart';
import 'prediction.dart';

/// Pure classification contract: one frame in, at most one label out.
///
/// Classifiers NEVER guess — null means "not recognized" and must feed the
/// stabilizer as a neutral frame. Gate concerns (calibration, freshness,
/// finger validity) live in [RefuseGate] and are applied by the
/// RecognitionController before this is called, so implementations assume
/// a gate-clean frame.
abstract interface class GestureClassifier {
  Prediction? classifyFrame(HandFrame frame);
}
