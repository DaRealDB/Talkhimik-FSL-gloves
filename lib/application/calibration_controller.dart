import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings/app_strings.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/cal_info_packet.dart';
import '../domain/models/device_status.dart';
import '../domain/models/telemetry_packet.dart';
import 'providers.dart';

/// Firmware-driven 10-step calibration wizard (master §4).
enum CalibrationPhase { idle, running, done }

/// The wizard mirrors the glove — the step shown is ALWAYS
/// STATUS.calibrationStep; nothing advances locally (master §4.2).
class CalibrationState {
  const CalibrationState({
    this.phase = CalibrationPhase.idle,
    this.hand = GloveHand.left,
    this.step = 0,
    this.capturePending = false,
    this.startCalibrationId = 0,
    this.calInfo,
    this.error,
    this.faultedFinger, // finger index for the error-4 wiring warning
  });

  final CalibrationPhase phase;
  final GloveHand hand;

  /// Mirrored from STATUS: 0 idle, 1–10 = thumb-flat … pinky-90.
  final int step;

  /// A capture was sent; the Capture button stays disabled until the next
  /// STATUS arrives (or the UI's 1.5 s timeout re-enables it).
  final bool capturePending;

  /// calibration_id seen when the run started; completion = mode back to 0
  /// AND CAL_INFO's id greater than this (master §4.2).
  final int startCalibrationId;

  /// Latest mirrored CAL_INFO (also cached per hand).
  final CalInfoPacket? calInfo;

  /// User-facing message (gating, error 2/3, completion).
  final String? error;

  /// Finger the firmware faulted (error 4) — "check wiring" in the summary.
  final int? faultedFinger;

  /// Wizard progress derived from the step: finger 0..4, flat vs bent90.
  int get fingerIndex => step == 0 ? 0 : (step - 1) ~/ 2;
  bool get isFlatStep => step.isOdd;

  CalibrationState copyWith({
    CalibrationPhase? phase,
    GloveHand? hand,
    int? step,
    bool? capturePending,
    int? startCalibrationId,
    CalInfoPacket? calInfo,
    String? error,
    int? faultedFinger,
  }) =>
      CalibrationState(
        phase: phase ?? this.phase,
        hand: hand ?? this.hand,
        step: step ?? this.step,
        capturePending: capturePending ?? this.capturePending,
        startCalibrationId: startCalibrationId ?? this.startCalibrationId,
        calInfo: calInfo ?? this.calInfo,
        error: error,
        faultedFinger: faultedFinger ?? this.faultedFinger,
      );
}

class CalibrationController extends Notifier<CalibrationState> {
  StreamSubscription<DeviceStatusPacket>? _statusSub;
  StreamSubscription<CalInfoPacket>? _calInfoSub;
  Timer? _captureTimeout;

  /// The glove this run drives; null when idle.
  GloveConnection? _connection;

  @override
  CalibrationState build() {
    ref.onDispose(() {
      _statusSub?.cancel();
      _calInfoSub?.cancel();
      _captureTimeout?.cancel();
    });
    return const CalibrationState();
  }

  GloveConnection _connectionFor(GloveHand hand) =>
      ref.read(hand == GloveHand.left
          ? gloveConnectionProvider
          : rightGloveConnectionProvider);

  /// Shows the cached (last known) profile for a hand while disconnected.
  Future<void> loadCached(GloveHand hand) async {
    final cached = await ref.read(calInfoCacheProvider).load(hand);
    if (cached != null) {
      state = state.copyWith(hand: hand, calInfo: cached);
    }
  }

  /// Begins the firmware wizard for [hand] (master §4.2):
  /// send 0x01 → wait for STATUS mode==1 && step==1.
  Future<void> start(GloveHand hand) async {
    await _bind(hand);
    final live = ref.read(liveControllerProvider).forHand(hand);
    state = state.copyWith(
      phase: CalibrationPhase.running,
      hand: hand,
      step: 0,
      capturePending: false,
      startCalibrationId: live.calInfo?.calibrationId ?? 0,
      calInfo: live.calInfo ?? state.calInfo,
      error: null,
      faultedFinger: null,
    );
    await _connection!.sendCommand(AppCommand.startCalibration);
  }

  /// Sends the capture for the CURRENT step (odd = flat → 0x02, even =
  /// bent90 → 0x03). The button re-enables on the next STATUS or after the
  /// 1.5 s fallback (master §4.2).
  Future<void> capture() async {
    if (state.phase != CalibrationPhase.running ||
        state.capturePending ||
        state.step == 0) {
      return;
    }
    await _connection!.sendCommand(
        state.isFlatStep ? AppCommand.captureFlat : AppCommand.capture90);
    state = state.copyWith(capturePending: true, error: null);
    _captureTimeout?.cancel();
    _captureTimeout = Timer(const Duration(milliseconds: 1500), () {
      state = state.copyWith(capturePending: false);
    });
  }

  /// CANCEL (0x04): discards the in-progress run; the previous profile
  /// stays on the glove (master §4.2).
  Future<void> cancel() async {
    _captureTimeout?.cancel();
    if (_connection != null && state.phase == CalibrationPhase.running) {
      await _connection!.sendCommand(AppCommand.cancelCalibration);
    }
    state = const CalibrationState();
  }

  /// Back to idle after reviewing the done summary.
  void resetToIdle() => state = const CalibrationState();

  Future<void> _bind(GloveHand hand) async {
    await _statusSub?.cancel();
    await _calInfoSub?.cancel();
    _connection = _connectionFor(hand);
    _statusSub = _connection!.deviceStatus.listen(_onStatus);
    _calInfoSub = _connection!.calInfo.listen(_onCalInfo);
  }

  void _onStatus(DeviceStatusPacket s) {
    if (state.phase == CalibrationPhase.idle) return;
    if (state.phase == CalibrationPhase.done) return;

    if (s.mode == GloveMode.calibrating) {
      // The glove drives the step; resync and re-enable Capture. The
      // faulted finger comes from the NEW step (error 4 marks the finger
      // the wizard is currently on).
      final newStep = s.calibrationStep;
      final faulted =
          s.lastErrorCode == 4 ? (newStep - 1) ~/ 2 : null;
      state = state.copyWith(
        step: newStep,
        capturePending: false,
        faultedFinger: faulted ?? state.faultedFinger,
        error: _errorMessage(s.lastErrorCode),
      );
      return;
    }

    // mode returned to streaming: completed (id increased) or aborted.
    if (s.mode == GloveMode.streaming) {
      // CAL_INFO notify may race the mode flip — check both mirrors.
      final liveId = ref
          .read(liveControllerProvider)
          .forHand(state.hand)
          .calInfo
          ?.calibrationId ??
          0;
      final latestId = state.calInfo?.calibrationId ?? liveId;
      // Uncalibrated start (id 0) → any new id completes (master §4.2).
      final completed = latestId > state.startCalibrationId;
      state = state.copyWith(
        phase: completed ? CalibrationPhase.done : CalibrationPhase.idle,
        capturePending: false,
        step: 0,
        error: null,
      );
    }
  }

  void _onCalInfo(CalInfoPacket c) {
    // Mirror into state only — the cache write lives in the live
    // controller, which is always bound; the glove stays the authority
    // (master §4.1).
    state = state.copyWith(calInfo: c);
    // The firmware pushes CAL_INFO right after a save while mode is still
    // calibrating; completion is re-checked when mode returns to 0.
  }

  /// Firmware STATUS errors → user copy (master §4.3). Error 3 keeps the
  /// step (the firmware rejects and stays); error 4 advances (the glove
  /// marks the finger invalid and moves on); 1/2 are informational.
  String? _errorMessage(int? code) => switch (code) {
        3 => AppStrings.calibrationSpanReject,
        4 => AppStrings.calibrationWiringWarning,
        2 => AppStrings.calibrationUnknownCommand,
        _ => null,
      };
}
