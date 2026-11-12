import 'gesture_classifier.dart';
import 'mlp_classifier.dart';
import 'model_bundle.dart';
import 'threshold_classifier.dart';
import '../models/telemetry_packet.dart';

/// Picks the classifier for the active signing hand (C4):
///  * a valid trained model whose labels.json hand matches → [DartMlpClassifier]
///  * anything else (no assets, wrong hand, corrupt files) → [ThresholdClassifier]
///
/// The pure-Dart MLP engine is the primary model runner (see
/// mlp_classifier.dart for why); a TFLite engine can be added here later
/// behind the same [GestureClassifier] seam.
class ClassifierFactory {
  const ClassifierFactory();

  GestureClassifier create(ModelBundle? bundle, GloveHand signingHand) {
    final labels = bundle?.labels;
    if (labels != null && labels.validFor(signingHand)) {
      return DartMlpClassifier(bundle!);
    }
    return const ThresholdClassifier();
  }
}
