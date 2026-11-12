import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/domain/classifier/stabilizer.dart';

/// Drives the stabilizer with [label] frames every [stepMs] starting at
/// [start], returning the emitted labels in order.
List<String> run(
  Stabilizer stabilizer,
  List<String?> labels, {
  DateTime? start,
  int stepMs = 50,
}) {
  final emits = <String>[];
  var t = start ?? DateTime.fromMillisecondsSinceEpoch(1000);
  for (final label in labels) {
    final r = stabilizer.addFrame(label, t);
    if (r.emitLabel != null) emits.add(r.emitLabel!);
    t = t.add(Duration(milliseconds: stepMs));
  }
  return emits;
}

void main() {
  test('a stable pose emits exactly once, no matter how long it is held',
      () {
    final s = Stabilizer();
    final emits = run(s, List.filled(40, 'A'));
    expect(emits, ['A']);
  });

  test('one or two flicker frames never emit', () {
    final s = Stabilizer();
    final emits = run(s, ['A', 'A', null, null, null, null, null, null,
        null, null, null, null, null, null, null, null, null, null, null, null]);
    expect(emits, isEmpty);
  });

  test('the same letter twice requires a release (neutral >= 400 ms) in '
      'between', () {
    final s = Stabilizer();
    final emits = run(s, [
      ...List.filled(20, 'A'), // hold A -> emits
      // 19 neutral frames: A's votes drop below majority after ~11, then
      // the 400 ms release clock runs (8 more frames).
      ...List.filled(19, null),
      ...List.filled(20, 'A'), // hold A again -> emits again
    ]);
    expect(emits, ['A', 'A']);
  });

  test('a shorter neutral gap does NOT arm the release: no second A', () {
    final s = Stabilizer();
    final emits = run(s, [
      ...List.filled(20, 'A'), // emits
      ...List.filled(6, null), // only 300 ms neutral
      ...List.filled(20, 'A'), // same letter, no release -> held
    ]);
    expect(emits, ['A']);
  });

  test('changing to a different letter emits without a release', () {
    final s = Stabilizer();
    final emits = run(s, [
      ...List.filled(20, 'A'),
      ...List.filled(20, 'B'), // different letter -> change is enough
    ]);
    expect(emits, ['A', 'B']);
  });

  test('emissions respect the 400 ms minimum gap', () {
    final s = Stabilizer();
    // A holds and emits at the frame its majority first appears (t=1180).
    // B votes then arrive at 50 Hz: B's majority appears at t=1580, exactly
    // 400 ms after A's emission — the boundary passes, and the emission is
    // not duplicated afterwards.
    final emits = <String>[];
    var t = DateTime.fromMillisecondsSinceEpoch(1000);
    for (final label in [
      ...List.filled(20, 'A'),
      ...List.filled(30, 'B'),
    ]) {
      final r = s.addFrame(label, t);
      if (r.emitLabel != null) emits.add(r.emitLabel!);
      t = t.add(const Duration(milliseconds: 20));
    }
    expect(emits, ['A', 'B']);
  });

  test('a tie at the majority threshold goes to the most recent class', () {
    final s = Stabilizer();
    final emits = <String>[];
    var t = DateTime.fromMillisecondsSinceEpoch(1000);
    for (final label in [
      ...List.filled(10, 'A'),
      ...List.filled(10, 'B'),
    ]) {
      final r = s.addFrame(label, t);
      if (r.emitLabel != null) emits.add(r.emitLabel!);
      t = t.add(const Duration(milliseconds: 50));
    }
    // Window = [A x10, B x10]: the tie goes to the most recent class (B).
    expect(emits, ['A', 'B']);
  });

  test('reset() clears the window: the same letter emits again without a '
      'release', () {
    final s = Stabilizer();
    final emits = run(s, List.filled(20, 'A'));
    expect(emits, ['A']);
    s.reset();
    final after = run(s, List.filled(20, 'A'),
        start: DateTime.fromMillisecondsSinceEpoch(5000));
    expect(after, ['A']);
  });

  test('vote share is majority votes over the configured window size', () {
    final s = Stabilizer();
    var t = DateTime.fromMillisecondsSinceEpoch(1000);
    StabilizerFrameResult? result;
    for (var i = 0; i < 15; i++) {
      result = s.addFrame('A', t);
      t = t.add(const Duration(milliseconds: 50));
    }
    // 15 A votes in the window -> share 15/20 = 0.75.
    expect(result!.voteCount, 15);
    expect(result.voteShare, 0.75);
  });
}
