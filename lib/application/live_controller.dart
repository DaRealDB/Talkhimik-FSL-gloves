import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/glove/glove_connection.dart';
import '../domain/models/cal_info_packet.dart';
import '../domain/models/device_status.dart';
import '../domain/models/hand_state.dart';
import '../domain/models/telemetry_packet.dart';
import '../domain/sensing/sensor_math.dart';
import 'providers.dart';

/// Both gloves' live snapshots for the /live screen (master §6.1, §7.3).
class LiveState {
  const LiveState({
    this.left = const HandState(hand: GloveHand.left),
    this.right = const HandState(hand: GloveHand.right),
  });

  final HandState left;
  final HandState right;

  HandState forHand(GloveHand hand) =>
      hand == GloveHand.left ? left : right;

  LiveState copyWith({HandState? left, HandState? right}) => LiveState(
        left: left ?? this.left,
        right: right ?? this.right,
      );
}

/// Folds each glove's contract streams into a [HandState]: latest packets,
/// wrap-safe seq-gap loss, trailing-second update rate, and the hand-byte
/// mismatch warning (the data is trusted, the badge warns — §7.3).
class LiveController extends Notifier<LiveState> {
  final List<StreamSubscription<Object?>> _subs = [];
  final List<DateTime> _leftFrameTimes = [];
  final List<DateTime> _rightFrameTimes = [];

  @override
  LiveState build() {
    // watch, not read: a Force-mock toggle swaps the connections and the
    // live state must rebind to the new instances.
    _bind(ref.watch(gloveConnectionProvider), GloveHand.left);
    _bind(ref.watch(rightGloveConnectionProvider), GloveHand.right);
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
    });
    return const LiveState();
  }

  void _bind(GloveConnection connection, GloveHand expected) {
    _subs.add(connection.telemetry.listen((t) => _onTelemetry(expected, t)));
    _subs.add(connection.deviceStatus.listen((s) => _onStatus(expected, s)));
    _subs.add(connection.calInfo.listen((c) => _onCalInfo(expected, c)));
  }

  void _onTelemetry(GloveHand expected, TelemetryPacket t) {
    final isLeft = expected == GloveHand.left;
    final current = isLeft ? state.left : state.right;
    final times = isLeft ? _leftFrameTimes : _rightFrameTimes;
    final now = t.receivedAt;

    times.add(now);
    while (times.isNotEmpty &&
        now.difference(times.first) > const Duration(seconds: 1)) {
      times.removeAt(0);
    }

    // Wrap-safe gap vs the previous frame (master §5.1).
    final prevSeq = current.telemetry?.seq;
    final lost =
        prevSeq == null ? 0 : seqGap(prevSeq, t.seq);

    final next = current.copyWith(
      telemetry: t,
      receivedFrames: current.receivedFrames + 1,
      lostFrames: current.lostFrames + lost,
      lastFrameAt: now,
      updateRateHz: times.length.toDouble(),
      handMismatch: current.handMismatch || t.hand != expected,
    );
    state = isLeft ? state.copyWith(left: next) : state.copyWith(right: next);
  }

  void _onStatus(GloveHand expected, DeviceStatusPacket s) {
    final isLeft = expected == GloveHand.left;
    final current = isLeft ? state.left : state.right;
    final next = current.copyWith(status: s);
    state = isLeft ? state.copyWith(left: next) : state.copyWith(right: next);
  }

  void _onCalInfo(GloveHand expected, CalInfoPacket c) {
    // Mirror into the per-hand cache (master §4.5) — this controller is
    // always bound, so every CAL_INFO notify lands here; the glove's NVS
    // stays the authority.
    unawaited(ref.read(calInfoCacheProvider).save(expected, c));
    final isLeft = expected == GloveHand.left;
    final current = isLeft ? state.left : state.right;
    final next = current.copyWith(calInfo: c);
    state = isLeft ? state.copyWith(left: next) : state.copyWith(right: next);
  }
}
