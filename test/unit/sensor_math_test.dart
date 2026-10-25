import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/sensing/sensor_math.dart';

void main() {
  group('adcToOhms golden vectors (master §3)', () {
    test('R_DIV 10000, adc 1365 → 20000 Ω', () {
      expect(adcToOhms(10000, 1365), 20000.0);
    });

    test('R_DIV 10000, adc 2048 → ≈9995.12 Ω', () {
      expect(adcToOhms(10000, 2048), closeTo(9995.12, 0.01));
    });

    test('rail readings saturate: adc 0 → huge, adc 4095 → ~0', () {
      expect(adcToOhms(10000, 0), double.maxFinite);
      expect(adcToOhms(10000, 4095), 0.0);
    });
  });

  group('ohmsToAngle golden vectors (master §3)', () {
    test('rising resistance: flat 10k, bent90 30k, R 20k → 45°', () {
      expect(ohmsToAngle(20000, 10000, 30000), 45.0);
    });

    test('falling resistance: flat 30k, bent90 10k, R 20k → 45°', () {
      expect(ohmsToAngle(20000, 30000, 10000), 45.0);
    });

    test('clamps to 0..90', () {
      expect(ohmsToAngle(40000, 10000, 30000), 90.0);
      expect(ohmsToAngle(5000, 10000, 30000), 0.0);
    });

    test('degenerate span → 0', () {
      expect(ohmsToAngle(20000, 10000, 10000), 0.0);
    });
  });

  group('seqGap (wrap-safe, master §11)', () {
    test('wrap: last 65535, now 0 → 0', () {
      expect(seqGap(65535, 0), 0);
    });

    test('last 10, now 14 → 3', () {
      expect(seqGap(10, 14), 3);
    });

    test('last 10, now 15 → 4', () {
      expect(seqGap(10, 15), 4);
    });
  });
}
