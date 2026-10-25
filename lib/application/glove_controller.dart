import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/gatt_ids.dart';
import '../core/strings/app_strings.dart';
import '../data/glove/ble_permissions.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/cal_info_packet.dart';
import '../domain/models/device_status.dart';
import '../domain/models/telemetry_packet.dart';
import 'providers.dart'; // composition root (Riverpod-idiomatic cycle)

/// UI-facing connection state (FR-12).
class GloveState {
  const GloveState({
    this.phase = GloveConnectionPhase.disconnected,
    this.status,
    this.telemetry,
    this.calInfo,
    this.connectionLost = false,
    this.reconnectAttempt = 0,
    this.connectError,
  });

  final GloveConnectionPhase phase;
  final DeviceStatusPacket? status;

  /// Latest decoded 29-byte sensor frame (null until the glove streams).
  final TelemetryPacket? telemetry;

  /// Latest calibration table read from the glove (calId, firmware
  /// version, validity masks).
  final CalInfoPacket? calInfo;

  /// True while the link is down for a reason other than a deliberate
  /// disconnect — drives the visible "connection lost" banner (C-S5).
  final bool connectionLost;

  /// How many auto-reconnect attempts have fired (for the status bar).
  final int reconnectAttempt;

  /// Friendly message from the last EXPLICIT connect attempt; the caller
  /// surfaces it once (snackbar). Auto-reconnects never set this.
  final String? connectError;

  GloveState copyWith({
    GloveConnectionPhase? phase,
    DeviceStatusPacket? status,
    TelemetryPacket? telemetry,
    CalInfoPacket? calInfo,
    bool? connectionLost,
    int? reconnectAttempt,
    String? connectError,
  }) =>
      GloveState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        telemetry: telemetry ?? this.telemetry,
        calInfo: calInfo ?? this.calInfo,
        connectionLost: connectionLost ?? this.connectionLost,
        reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
        connectError: connectError,
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
  /// Injectable for tests; production uses [Future.delayed]. The optional
  /// [connectionProvider] rebinds the controller to a specific glove (the
  /// right-hand controller passes [rightGloveConnectionProvider]); the
  /// default is the keep-area primary (left) connection.
  GloveController([
    this._delay = Future<void>.delayed,
    this.connectionProvider,
  ]);

  final Future<void> Function(Duration) _delay;
  final Provider<GloveConnection>? connectionProvider;

  StreamSubscription<DeviceStatusPacket>? _statusSub;
  StreamSubscription<TelemetryPacket>? _telemetrySub;
  StreamSubscription<CalInfoPacket>? _calInfoSub;
  StreamSubscription<GloveConnectionPhase>? _phaseSub;
  bool _manualDisconnect = false;
  bool _explicitConnectInFlight = false;
  int _attempt = 0;
  int _generation = 0;

  @override
  GloveState build() {
    final connection = ref.read(connectionProvider ?? gloveConnectionProvider);
    _statusSub =
        connection.deviceStatus.listen((s) => state = state.copyWith(status: s));
    _telemetrySub = connection.telemetry
        .listen((t) => state = state.copyWith(telemetry: t));
    _calInfoSub = connection.calInfo
        .listen((c) => state = state.copyWith(calInfo: c));
    _phaseSub = connection.phaseChanges.listen(_onPhase);
    ref.onDispose(() {
      _statusSub?.cancel();
      _telemetrySub?.cancel();
      _calInfoSub?.cancel();
      _phaseSub?.cancel();
    });
    return const GloveState();
  }

  /// Manual connect (e.g. user taps "Connect"); clears the manual-disconnect
  /// flag so a later link drop auto-reconnects again. A failed attempt
  /// records a friendly message (surfaced by the caller) and resets the
  /// phase without scheduling a reconnect — the user retries explicitly.
  Future<void> connect() async {
    _manualDisconnect = false;
    _explicitConnectInFlight = true;
    state = state.copyWith(connectError: null);
    try {
      await ref.read(connectionProvider ?? gloveConnectionProvider).connect();
    } catch (e) {
      state = state.copyWith(
        phase: GloveConnectionPhase.disconnected,
        connectError: e is BlePermissionDeniedException
            ? AppStrings.blePermissionDenied
            : AppStrings.connectFailed,
      );
    } finally {
      _explicitConnectInFlight = false;
    }
  }

  /// Deliberate teardown: no "connection lost" banner, no auto-reconnect.
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _cancelPendingReconnect();
    await ref.read(connectionProvider ?? gloveConnectionProvider).disconnect();
  }

  void _onPhase(GloveConnectionPhase phase) {
    final lost = phase == GloveConnectionPhase.disconnected &&
        !_manualDisconnect &&
        !_explicitConnectInFlight;
    final restored = phase == GloveConnectionPhase.ready ||
        phase == GloveConnectionPhase.connecting ||
        phase == GloveConnectionPhase.discoveringServices;

    if (restored) {
      // Link restored (or being restored): banner off, backoff reset.
      _attempt = 0;
      state = state.copyWith(
        phase: phase,
        connectionLost: false,
        connectError: null,
      );
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
      await ref.read(connectionProvider ?? gloveConnectionProvider).reconnect();
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
