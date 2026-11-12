import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/classifier/classifier_factory.dart';
import 'package:talkhimik_app/domain/classifier/mlp_classifier.dart';
import 'package:talkhimik_app/domain/classifier/model_bundle.dart';
import 'package:talkhimik_app/domain/classifier/threshold_classifier.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

const labelsL = '''
{
  "version": 1, "hand": "L", "rest_class": "_rest",
  "input_spec": {"order": ["ang_thumb","ang_pointer","ang_middle",
    "ang_ring","ang_pinky"], "units": 5, "variant": "A"},
  "classes": [
    {"index": 0, "label": "A", "word_id": 1},
    {"index": 1, "label": "_rest", "word_id": 0}
  ],
  "confidence_floor": 0.5, "floor_precision_95": true,
  "trained_on": {"dataset_hash": "abc123", "signers": ["P-001"]}
}
''';

const weightsJson = '''
{
  "input_order": ["ang_thumb","ang_pointer","ang_middle","ang_ring",
    "ang_pinky"],
  "classes": ["A", "_rest"],
  "layers": [
    {"weights": [[0.002222, -0.002222], [0.002222, -0.002222],
      [0.002222, -0.002222], [0.002222, -0.002222],
      [0.002222, -0.002222]],
     "bias": [0, 1]},
    {"weights": [[10, -10], [-10, 10]], "bias": [0, 0]}
  ]
}
''';

void main() {
  const factory = ClassifierFactory();
  final bundle = ModelBundle.assemble(labelsL, weightsJson)!;

  test('no bundle falls back to the threshold rules', () {
    expect(factory.create(null, GloveHand.left), isA<ThresholdClassifier>());
  });

  test('a model whose hand matches the signing hand is used', () {
    expect(
        factory.create(bundle, GloveHand.left), isA<DartMlpClassifier>());
  });

  test('a model trained for the other hand falls back to the rules', () {
    expect(factory.create(bundle, GloveHand.right),
        isA<ThresholdClassifier>());
  });

  test('corrupt assets never reach the factory — the loader yields null',
      () {
    expect(ModelBundle.assemble('bad', weightsJson), isNull);
    expect(factory.create(null, GloveHand.left), isA<ThresholdClassifier>());
  });
}
