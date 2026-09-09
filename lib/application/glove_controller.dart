import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/gatt_ids.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/device_status.dart';
import 'providers.dart'; // composition root (Riverpod-idiomatic cycle)

/// UI-facing connection state (FR-12).
class GloveState {
  const GloveState({
    this.phase = GloveConnectionPhase.disconnected,
    this.status,
    this.connectionLost = false,
    this.reconnectAttempt = 0,
  });

  final GloveConnectionPhase phase;
  final DeviceStatusPacket? status;

  /// True while the link is down for a reason other than a deliberate
  /// disconnect — drives the visible "connection lost" banner (C-S5).
  final bool connectionLost;

  /// How many auto-reconnect attempts have fired (for the status bar).
  final int reconnectAttempt;

  GloveState copyWith({
    GloveConnectionPhase? phase,
    DeviceStatusPacket? status,
    bool? connectionLost,
    int? reconnectAttempt,
  }) =>
      GloveState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        connectionLost: connectionLost ?? this.connectionLost,
        reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      );
}

/// Owns the connection lifecycle: phase tracking, device status, and the
/// auto-reconnect state machine (SRS C-S5, C-F7, NFR-9).
///
/// Reconnect backoff follows [ReconnectPolicy.backoffSeconds]: 1, 2, 4, 8,
/// then capped at 30 s. The "connection lost" flag is set IMMEDIATELY when
/// the phase leaves `ready` (well inside the 3-second bound from C-S5) —
/// the banner does not wait for the reconnect attempt to fail.
class GloveController extends Notifier<GloveState> {
  /// Injectable for tests; production uses [Future.delayed].
  GloveController([this._delay = Future<void>.delayed]);

  final Future<void> Function(Duration) _delay;

  StreamSubscription<DeviceStatusPacket>? _statusSub;
  StreamSubscription<GloveConnectionPhase>? _phaseSub;
  bool _manualDisconnect = false;
  int _attempt = 0;
  int _generation = 0;

  @override
  GloveState build() {
    final connection = ref.read(gloveConnectionProvider);
    _statusSub =
        connection.deviceStatus.listen((s) => state = state.copyWith(status: s));
    _phaseSub = connection.phaseChanges.listen(_onPhase);
    ref.onDispose(() {
      _statusSub?.cancel();
      _phaseSub?.cancel();
    });
    return const GloveState();
  }

  /// Manual connect (e.g. user taps "Connect"); clears the manual-disconnect
  /// flag so a later link drop auto-reconnects again.
  Future<void> connect() async {
    _manualDisconnect = false;
    await ref.read(gloveConnectionProvider).connect();
  }

  /// Deliberate teardown: no "connection lost" banner, no auto-reconnect.
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _cancelPendingReconnect();
    await ref.read(gloveConnectionProvider).disconnect();
  }

  void _onPhase(GloveConnectionPhase phase) {
    final lost =
        phase == GloveConnectionPhase.disconnected && !_manualDisconnect;
    final restored = phase == GloveConnectionPhase.ready ||
        phase == GloveConnectionPhase.connecting ||
        phase == GloveConnectionPhase.discoveringServices;

    if (restored) {
      // Link restored (or being restored): banner off, backoff reset.
      _attempt = 0;
      state = state.copyWith(phase: phase, connectionLost: false);
    } else if (lost) {
      _scheduleReconnect();
      state = state.copyWith(phase: phase, connectionLost: true);
    } else {
      // Deliberate disconnect (no banner), or a transient phase such as
      // `reconnecting`: keep the banner as-is.
      state = state.copyWith(
        phase: phase,
        connectionLost: state.connectionLost,
      );
    }
  }

  void _scheduleReconnect() {
    final generation = ++_generation;
    final attempt = _attempt++;
    final step = attempt < ReconnectPolicy.backoffSeconds.length
        ? ReconnectPolicy.backoffSeconds[attempt]
        : ReconnectPolicy.backoffSeconds.last;
    // ignore: discarded_futures — fire-and-forget by design
    _runReconnect(generation, Duration(seconds: step));
  }

  Future<void> _runReconnect(int generation, Duration wait) async {
    await _delay(wait);
    if (!ref.mounted || generation != _generation) return;
    state = state.copyWith(reconnectAttempt: state.reconnectAttempt + 1);
    try {
      await ref.read(gloveConnectionProvider).reconnect();
    } catch (_) {
      // Attempt failed (glove out of range or busy). While the link is
      // still down, keep trying with the next, longer backoff step.
      // Never surface raw exceptions to the UI.
      if (ref.mounted && state.phase == GloveConnectionPhase.disconnected) {
        _scheduleReconnect();
      }
    }
  }

  void _cancelPendingReconnect() {
    _generation++; // invalidates any in-flight _runReconnect
  }
}
