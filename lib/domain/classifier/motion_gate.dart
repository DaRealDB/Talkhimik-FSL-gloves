/// Motion letters (J): the model knows only the handshape, so the letter is
/// emitted only while the hand's pitch has changed by at least the trained
/// amount within the window (labels.json `motion_labels`). Pitch, not roll
/// (wraps at ±180) or yaw (drifts).
class MotionGate {
  MotionGate({this.window = const Duration(milliseconds: 1500)});

  final Duration window;
  final List<(DateTime, double)> _pitch = [];

  /// Records one frame's pitch and forgets frames older than [window].
  void add(DateTime at, double pitchDeg) {
    _pitch.add((at, pitchDeg));
    while (_pitch.isNotEmpty && at.difference(_pitch.first.$1) > window) {
      _pitch.removeAt(0);
    }
  }

  /// Max − min pitch over the window (0 with fewer than 2 frames).
  double get span {
    if (_pitch.length < 2) return 0;
    var lo = _pitch.first.$2, hi = lo;
    for (final (_, p) in _pitch) {
      if (p < lo) lo = p;
      if (p > hi) hi = p;
    }
    return hi - lo;
  }

  /// Whether [label] may be emitted now: always for a still letter; for a
  /// motion letter only once the pitch moved at least its trained span.
  bool allows(String label, Map<String, double> minSpanByLabel) {
    final min = minSpanByLabel[label];
    return min == null || span >= min;
  }

  void reset() => _pitch.clear();
}
