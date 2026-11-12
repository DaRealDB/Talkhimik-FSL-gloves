import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/classifier/model_bundle.dart';

/// Loads the shipped model assets (labels.json + weights.json) and
/// assembles a validated [ModelBundle]. A missing or corrupt asset —
/// including a model trained for the other hand — yields null, and the
/// app falls back to the C1 threshold rules. The app must work with no
/// model present.
class ModelAssetLoader {
  ModelAssetLoader([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String labelsPath = 'assets/models/labels.json';
  static const String weightsPath = 'assets/models/weights.json';

  Future<ModelBundle?> load() async {
    try {
      final labels = await _bundle.loadString(labelsPath);
      final weights = await _bundle.loadString(weightsPath);
      return ModelBundle.assemble(labels, weights);
    } catch (_) {
      // FlutterError from loadString (asset absent) or an assemble null —
      // both mean "no usable model": threshold rules take over.
      return null;
    }
  }
}
