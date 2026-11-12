import 'package:meta/meta.dart';

/// Stabilizer tuning — the ONE file to change when the hold-to-confirm
/// feel needs adjusting (C1/C4 share these constants).
class StabilizerConfig {
  const StabilizerConfig({
    this.windowSize = 20,
    this.majorityVotes = 10,
    this.releaseMs = 400,
    this.minEmissionGapMs = 400,
  });

  /// Ring-buffer depth in frames (20 frames @ 20 Hz = 1 s of sign).
  final int windowSize;

  /// A class must hold at least this many votes to become the majority.
  final int majorityVotes;

  /// Neutral (REST/no-majority) held this long counts as a release.
  final int releaseMs;

  /// Hard floor between two emissions.
  final int minEmissionGapMs;
}

/// What [Stabilizer.addFrame] observed this frame.
@immutable
class StabilizerFrameResult {
  const StabilizerFrameResult({
    this.majorityLabel,
    required this.voteCount,
    required this.voteShare,
    this.emitLabel,
    required this.neutralReleased,
  });

  /// Label holding the majority this frame (null = neutral).
  final String? majorityLabel;

  /// Votes for [majorityLabel] (0 when neutral).
  final int voteCount;

  /// [voteCount] / windowSize — the multiplier for classifier confidence.
  final double voteShare;

  /// Letter to emit THIS frame, or null. Applies the release and
  /// minimum-gap rules; the caller maps it to a word_id.
  final String? emitLabel;

  /// Neutral has persisted ≥ releaseMs — a release is currently armed.
  final bool neutralReleased;
}

class _Frame {
  const _Frame(this.label, this.at);
  final String? label;
  final DateTime at;
}

/// Pure-Dart stabilizer: turns a per-frame classifier stream into
/// deliberate, once-per-sign emissions (concept C5: held steady →
/// one bubble; flicker → nothing).
///
/// Rules:
///  * sliding [StabilizerConfig.windowSize]-frame ring buffer;
///  * a label must hold ≥ [StabilizerConfig.majorityVotes] votes to count;
///  * it is emitted only when it differs from the last emitted label, or
///    after a release (neutral ≥ [StabilizerConfig.releaseMs]);
///  * the same letter twice in a row REQUIRES a release between;
///  * emissions are ≥ [StabilizerConfig.minEmissionGapMs] apart;
///  * [reset] clears everything (stale frames / disconnect).
class Stabilizer {
  Stabilizer({this.config = const StabilizerConfig()});

  final StabilizerConfig config;

  final List<_Frame> _window = [];
  String? _lastEmitted;
  DateTime? _lastEmitAt;
  bool _released = false;
  DateTime? _neutralSince;

  StabilizerFrameResult addFrame(String? label, DateTime now) {
    _window.add(_Frame(label, now));
    if (_window.length > config.windowSize) _window.removeAt(0);

    // Majority: ≥ majorityVotes votes; ties go to the most recent class.
    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final f in _window) {
      final l = f.label;
      if (l == null) continue;
      counts[l] = (counts[l] ?? 0) + 1;
      lastSeen[l] = f.at;
    }
    String? majority;
    var votes = 0;
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    counts.forEach((label, count) {
      if (count < config.majorityVotes) return;
      final seen = lastSeen[label]!;
      if (count > votes || (count == votes && seen.isAfter(latest))) {
        majority = label;
        votes = count;
        latest = seen;
      }
    });

    // Release tracking: neutral held ≥ releaseMs arms a release.
    if (majority == null) {
      _neutralSince ??= now;
      if (now.difference(_neutralSince!) >=
          Duration(milliseconds: config.releaseMs)) {
        _released = true;
      }
    } else {
      _neutralSince = null;
    }

    // Emission: change-of-label or post-release, respecting the min gap.
    String? emit;
    if (majority != null) {
      final gapOk = _lastEmitAt == null ||
          now.difference(_lastEmitAt!) >=
              Duration(milliseconds: config.minEmissionGapMs);
      if ((majority != _lastEmitted || _released) && gapOk) {
        emit = majority;
        _lastEmitted = majority;
        _lastEmitAt = now;
        _released = false;
      }
    }

    return StabilizerFrameResult(
      majorityLabel: majority,
      voteCount: votes,
      voteShare: votes / config.windowSize,
      emitLabel: emit,
      neutralReleased: _neutralSince != null &&
          now.difference(_neutralSince!) >=
              Duration(milliseconds: config.releaseMs),
    );
  }

  /// Clears the window and all state — call on stale frames and disconnect
  /// so a pre-drop pose can never emit after the glove goes quiet.
  void reset() {
    _window.clear();
    _lastEmitted = null;
    _lastEmitAt = null;
    _released = false;
    _neutralSince = null;
  }
}
