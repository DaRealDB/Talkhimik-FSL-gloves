import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/constants/confidence.dart';

void main() {
  group('ConfidenceThresholds.levelFor (defaults 80/60)', () {
    test('green at and above 80', () {
      expect(ConfidenceThresholds.levelFor(80), ConfidenceLevel.high);
      expect(ConfidenceThresholds.levelFor(100), ConfidenceLevel.high);
      expect(ConfidenceThresholds.levelFor(95), ConfidenceLevel.high);
    });

    test('amber from 60 to 79', () {
      expect(ConfidenceThresholds.levelFor(60), ConfidenceLevel.medium);
      expect(ConfidenceThresholds.levelFor(79), ConfidenceLevel.medium);
      expect(ConfidenceThresholds.levelFor(70), ConfidenceLevel.medium);
    });

    test('red below 60', () {
      expect(ConfidenceThresholds.levelFor(59), ConfidenceLevel.low);
      expect(ConfidenceThresholds.levelFor(0), ConfidenceLevel.low);
    });

    test('boundary just below amber stays red (59)', () {
      expect(ConfidenceThresholds.levelFor(59), ConfidenceLevel.low);
      expect(ConfidenceThresholds.levelFor(60), isNot(ConfidenceLevel.low));
    });

    test('custom thresholds are honored', () {
      expect(
        ConfidenceThresholds.levelFor(50, green: 90, amber: 50),
        ConfidenceLevel.medium,
      );
      expect(
        ConfidenceThresholds.levelFor(91, green: 90, amber: 50),
        ConfidenceLevel.high,
      );
    });
  });
}
