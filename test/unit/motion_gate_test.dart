import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/classifier/motion_gate.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
  const gates = {'J': 35.0};

  test('a motion letter needs the trained pitch change; still letters never',
      () {
    final g = MotionGate()
      ..add(at(0), 10)
      ..add(at(100), 12);
    expect(g.allows('J', gates), isFalse); // held still: 2 deg
    expect(g.allows('A', gates), isTrue);
    g.add(at(400), 60);
    expect(g.span, 50);
    expect(g.allows('J', gates), isTrue);
  });

  test('frames older than the window are forgotten', () {
    final g = MotionGate()
      ..add(at(0), 0)
      ..add(at(200), 80);
    expect(g.allows('J', gates), isTrue);
    g.add(at(2000), 80); // the 0-deg frame is now > 1.5 s old
    expect(g.allows('J', gates), isFalse);
  });
}
