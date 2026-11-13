import 'package:meta/meta.dart';

/// Operating mode reported by the glove through the Device Status
/// characteristic (firmware STATUS byte 0; Code Reference §5.3).
enum GloveMode { streaming, calibrating, unknown }

/// Error codes the glove can report through Device Status (STATUS byte 4;
/// Code Reference §5.3).
enum GloveErrorCode {
  none(0),
  captureNotCalibrating(1),
  unknownCommand(2),
  spanReject(3),
  resistanceFault(4),
  // fw 1.3.0 (config.h StatusError) — IMU mount / gyro calibration.
  imuMissing(5),
  mountGravity(6),
  mountNotPerpendicular(7),
  mountSequence(8),
  gyroMoving(9),
  gyroStuck(10);

  const GloveErrorCode(this.code);
  final int code;

  /// Null for codes the firmware does not define (the UI shows a generic
  /// "glove error" chip for those).
  static GloveErrorCode? fromCode(int? code) => switch (code) {
        1 => captureNotCalibrating,
        2 => unknownCommand,
        3 => spanReject,
        4 => resistanceFault,
        5 => imuMissing,
        6 => mountGravity,
        7 => mountNotPerpendicular,
        8 => mountSequence,
        9 => gyroMoving,
        10 => gyroStuck,
        0 || null => none,
        _ => null,
      };
}

/// Snapshot of the glove's Device Status characteristic — the firmware's
/// STATUS frame (Code Reference §5.3): mode, calibration step, battery,
/// flags, error code, and (fw 1.3.0+) mount_calibration_id.
@immutable
class DeviceStatusPacket {
  const DeviceStatusPacket({
    this.batteryPercent,
    this.mode = GloveMode.unknown,
    this.calibrationStep = 0,
    this.uncalibrated = false,
    this.linkUp = false,
    this.lastErrorCode,
    this.mountUncalibrated = false,
    this.gyroUncalibrated = false,
    this.mountCalibrationId,
  });

  /// Battery charge, 0–100; null when the glove did not report it
  /// (0xFF — the XIAO's VBAT divider is on ADC2 and is disabled).
  final int? batteryPercent;

  final GloveMode mode;

  /// Calibration wizard progress: 0 = idle, 1–10 = thumb-flat … pinky-90.
  final int calibrationStep;

  /// True while the glove streams placeholder angles (STATUS flags bit0) —
  /// the calibration wizard has not completed for this glove.
  final bool uncalibrated;

  /// True while the BLE link is up.
  final bool linkUp;

  /// Last error reported by the glove (GloveErrorCode values); null when
  /// none.
  final int? lastErrorCode;

  /// STATUS flags bit1 (fw 1.3.0+): no stored mount matrix, the firmware's
  /// default in use. Always false for fw 1.2.0 gloves.
  final bool mountUncalibrated;

  /// STATUS flags bit2 (fw 1.3.0+): gyro bias not measured.
  final bool gyroUncalibrated;

  /// STATUS bytes 5–8 (fw 1.3.0+): 0 = default mount, non-zero = the id of
  /// the saved mount calibration; null when the glove sends the 5-byte
  /// (fw 1.2.0) frame.
  final int? mountCalibrationId;

  bool get hasError => lastErrorCode != null && lastErrorCode != 0;
}
