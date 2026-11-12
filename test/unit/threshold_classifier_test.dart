import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/classifier/hand_frame.dart';
import 'package:talkhimik_app/domain/classifier/recognition_constants.dart';
import 'package:talkhimik_app/domain/classifier/threshold_classifier.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

HandFrame pose(List<double> angles) => HandFrame(
      hand: GloveHand.left,
      angles: angles,
      rollDeg: 0,
      pitchDeg: 0,
      yawDeg: 0,
      validMask: 0x1F,
      calibrationId: 3,
      uncalibratedFlag: false,
      timestamp: DateTime.now(),
    );

const classifier = ThresholdClassifier();

void main() {
  test('each of the 10 rules matches its canonical pose with the '
      'representative letter', () {
    final cases = <String, (String, List<double>)>{
      'FIST': ('A', [50, 70, 70, 70, 70]),
      'B': ('B', [80, 10, 10, 10, 10]),
      'F': ('F', [20, 10, 10, 10, 10]),
      'D-G-L': ('D', [60, 10, 70, 70, 70]),
      'V': ('V', [80, 10, 10, 70, 70]),
      'U-K-P': ('U', [20, 10, 10, 70, 70]),
      'W': ('W', [30, 10, 10, 10, 60]),
      'I': ('I', [80, 70, 70, 70, 10]),
      'Y': ('Y', [10, 70, 70, 70, 10]),
      'C': ('C', [40, 40, 40, 40, 40]),
    };
    for (final entry in cases.entries) {
      final pred = classifier.classifyFrame(pose(entry.value.$2));
      expect(pred, isNotNull, reason: entry.key);
      expect(pred!.className, entry.key);
      expect(pred.label, entry.value.$1);
    }
  });

  test('merged classes are never presented as certain: confidence capped '
      'at 0.55 with the phone-threshold source', () {
    final pred = classifier.classifyFrame(pose([50, 70, 70, 70, 70]));
    expect(pred!.confidence, RecognitionConstants.thresholdConfidenceCap);
    expect(pred.source, RecognitionConstants.thresholdSource);
  });

  test('a pose matching no rule returns null (never guess)', () {
    // Thumb mid, pointer mid, others mid — no rule covers it.
    expect(classifier.classifyFrame(pose([40, 40, 10, 40, 40])), isNull);
  });

  test('boundary between FIST and C goes to FIST (first match wins)', () {
    final pred = classifier.classifyFrame(pose([50, 65, 65, 65, 65]));
    expect(pred!.className, 'FIST');
  });

  test('exclusive bounds: 65 counts as ≥65 and <25 as max-exclusive', () {
    // I rule: pinky must be < 25 — 24 passes, 25 fails.
    expect(classifier.classifyFrame(pose([80, 70, 70, 70, 24]))!.label, 'I');
    expect(classifier.classifyFrame(pose([80, 70, 70, 70, 25])), isNull);
  });
}
