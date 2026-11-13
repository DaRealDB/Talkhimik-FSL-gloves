import 'dart:typed_data';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/device_status.dart';

/// Decoder for the firmware's Device Status payload (Code Reference §5.3,
/// every 250 ms). fw 1.2.0 sends 5 bytes; fw 1.3.0 appends 4:
///   [0] mode u8 — 0 streaming, 1 calibrating
///   [1] calibration step u8 — 0 idle, 1–10 = thumb-flat … pinky-90
///   [2] battery % u8 — 0xFF = unknown
///   [3] flags u8 — bit0 flex uncalibrated, bit1 mount uncalibrated,
///       bit2 gyro bias uncalibrated
///   [4] error u8 — GloveErrorCode values (0 = none)
///   [5..8] mount_calibration_id u32 LE (fw 1.3.0+; 0 = default mount)
class DeviceStatusCodec {
  DeviceStatusCodec._();

  /// Decodes one READ/NOTIFY payload. Throws [FormatException] when the
  /// payload is shorter than [GattIds.statusPacketLength] bytes. Longer
  /// payloads are accepted (the firmware only ever appends fields); the
  /// mount id is read only when all 4 of its bytes are present.
  static DeviceStatusPacket decode(Uint8List bytes) {
    if (bytes.length < GattIds.statusPacketLength) {
      throw FormatException(
        'Device status packet must be at least '
        '${GattIds.statusPacketLength} bytes (Code Reference §5.3), '
        'got ${bytes.length}',
      );
    }

    final battery = bytes[2];
    final flags = bytes[3];
    return DeviceStatusPacket(
      mode: _modeFromCode(bytes[0]),
      calibrationStep: bytes[1],
      batteryPercent: battery == 0xFF ? null : battery.clamp(0, 100),
      uncalibrated: flags & 0x01 != 0,
      mountUncalibrated: flags & 0x02 != 0,
      gyroUncalibrated: flags & 0x04 != 0,
      // A packet received over the live link implies the link is up.
      linkUp: true,
      lastErrorCode: bytes[4],
      mountCalibrationId:
          bytes.length >= GattIds.statusPacketLengthWithMount
              ? ByteData.sublistView(bytes)
                  .getUint32(5, Endian.little)
              : null,
    );
  }

  static GloveMode _modeFromCode(int code) => switch (code) {
        0 => GloveMode.streaming,
        1 => GloveMode.calibrating,
        _ => GloveMode.unknown,
      };
}
