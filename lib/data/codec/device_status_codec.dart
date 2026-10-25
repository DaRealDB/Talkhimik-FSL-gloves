import 'dart:typed_data';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/device_status.dart';

/// Strict decoder for the firmware's 5-byte Device Status payload
/// (Code Reference §5.3, every 250 ms):
///   [0] mode u8 — 0 streaming, 1 calibrating
///   [1] calibration step u8 — 0 idle, 1–10 = thumb-flat … pinky-90
///   [2] battery % u8 — 0xFF = unknown
///   [3] flags u8 — bit0 = uncalibrated (placeholder angles in use)
///   [4] error u8 — GloveErrorCode values (0 = none)
class DeviceStatusCodec {
  DeviceStatusCodec._();

  /// Decodes one READ/NOTIFY payload. Throws [FormatException] when the
  /// payload is not exactly [GattIds.statusPacketLength] bytes.
  static DeviceStatusPacket decode(Uint8List bytes) {
    if (bytes.length != GattIds.statusPacketLength) {
      throw FormatException(
        'Device status packet must be ${GattIds.statusPacketLength} bytes '
        '(Code Reference §5.3), got ${bytes.length}',
      );
    }

    final battery = bytes[2];
    return DeviceStatusPacket(
      mode: _modeFromCode(bytes[0]),
      calibrationStep: bytes[1],
      batteryPercent: battery == 0xFF ? null : battery.clamp(0, 100),
      uncalibrated: bytes[3] & 0x01 != 0,
      // A packet received over the live link implies the link is up.
      linkUp: true,
      lastErrorCode: bytes[4],
    );
  }

  static GloveMode _modeFromCode(int code) => switch (code) {
        0 => GloveMode.streaming,
        1 => GloveMode.calibrating,
        _ => GloveMode.unknown,
      };
}
