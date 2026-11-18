import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings/app_strings.dart';
import '../data/glove/glove_connection.dart';
import '../domain/models/device_status.dart';
import '../domain/models/telemetry_packet.dart';
import 'providers.dart';

/// fw 1.3.0 IMU mount calibration: gyro bias (0x0B), Pose 1 (0x09), Pose 2
/// (0x0A). STATUS has no progress field for it — each command's result is
/// the STATUS error byte (0 = ok) on the first packet after the glove's
/// ~2 s blocking capture; a good Pose 2 also sets a new mount id.
class MountCalibrationState {
  const MountCalibrationState({
    this.hand = GloveHand.left,
    this.pending,
    this.message,
    this.succeeded = false,
  });

  final GloveHand hand;

  /// The command waiting for its STATUS result; null when idle.
  final AppCommand? pending;

  /// User-facing result of the last command.
  final String? message;

  /// The last command succeeded ([message] is a confirmation).
  final bool succeeded;
}

class MountCalibrationController extends Notifier<MountCalibrationState> {
  /// STATUS packets this soon after the write may predate the command.
  static const staleWindow = Duration(milliseconds: 300);

  /// No usable STATUS by then. A capture takes ~2 s, but I2C retries on a
  /// flaky IMU bus can stretch it well past that, so allow 15 s.
  static const timeout = Duration(seconds: 15);

  StreamSubscription<DeviceStatusPacket>? _sub;
  Timer? _timeout;
  Timer? _staleTimer;

  @override
  MountCalibrationState build() {
    ref.onDispose(_stop);
    return const MountCalibrationState();
  }

  /// Sends [command] to [hand]'s glove and resolves on its STATUS result.
  Future<void> run(GloveHand hand, AppCommand command) async {
    if (state.pending != null) return;
    _stop();
    final connection = ref.read(hand == GloveHand.left
        ? gloveConnectionProvider
        : rightGloveConnectionProvider);
    state = MountCalibrationState(hand: hand, pending: command);
    // Timers, not DateTime.now(), so widget tests' fake clock drives it.
    var accepting = false;
    _staleTimer = Timer(staleWindow, () => accepting = true);
    _sub = connection.deviceStatus.listen((s) {
      if (accepting) _finish(command, s.lastErrorCode ?? 0);
    });
    _timeout = Timer(timeout, () => _finish(command, null));
    await connection.sendCommand(command);
  }

  void _finish(AppCommand command, int? error) {
    _stop();
    final ok = error == 0;
    state = MountCalibrationState(
      hand: state.hand,
      succeeded: ok,
      message: ok
          ? switch (command) {
              AppCommand.captureMountPose1 => AppStrings.mountPose1Ok,
              AppCommand.captureMountPose2 => AppStrings.mountSaved,
              _ => AppStrings.mountGyroOk,
            }
          : messageFor(error),
    );
  }

  void _stop() {
    _timeout?.cancel();
    _timeout = null;
    _staleTimer?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Plain-language text for a STATUS error after a mount/gyro command
  /// (config.h StatusError); null = no reply in time.
  static String messageFor(int? error) => switch (error) {
        null => AppStrings.mountNoReply,
        2 => AppStrings.mountNeedsNewFirmware, // ERR_UNKNOWN_CMD
        5 || 10 => AppStrings.mountSensorNotResponding, // IMU missing / stuck
        6 => AppStrings.mountHoldStill, // ERR_MOUNT_GRAVITY
        7 => AppStrings.mountNotPerpendicular, // ERR_MOUNT_NOT_PERP
        8 => AppStrings.mountPose1First, // ERR_MOUNT_SEQUENCE
        9 => AppStrings.mountGyroMoving, // ERR_GYRO_MOVING
        _ => AppStrings.gloveError,
      };
}
