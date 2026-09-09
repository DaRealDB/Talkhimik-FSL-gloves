import 'dart:typed_data';

import '../../domain/models/device_status.dart';

/// Strict little-endian decoder for the 3-byte Device Status payload
/// (SRS Table III-1: battery %, active mode, last error code).
///
/// Byte layout is NOT pinned by the SRS (open item 2, like the UUIDs) and
/// must be finalized with the firmware team before firmware freeze:
///   [0] battery percent u8 (0–100)
///   [1] mode u8 — 0 idle, 1 streaming, 2 calibrating, 3 sleeping
///   [2] last error code u8 — GloveErrorCode values (0 = none)
class DeviceStatusCodec {
  DeviceStatusCodec._();

  static const int packetLength = 3;

  /// Decodes one READ/NOTIFY payload. Throws [FormatException] when the
  /// payload is not exactly 3 bytes.
  static DeviceStatusPacket decode(Uint8List bytes) {
    if (bytes.length != packetLength) {
      throw FormatException(
        'Device status packet must be $packetLength bytes '
        '(battery u8 + mode u8 + error u8), got ${bytes.length}',
      );
    }

    return DeviceStatusPacket(
      batteryPercent: bytes[0].clamp(0, 100),
      mode: _modeFromCode(bytes[1]),
      // A packet received over the live link implies the link is up.
      linkUp: true,
      lastErrorCode: bytes[2],
    );
  }

  static GloveMode _modeFromCode(int code) => switch (code) {
        0 => GloveMode.idle,
        1 => GloveMode.streaming,
        2 => GloveMode.calibrating,
        3 => GloveMode.sleeping,
        _ => GloveMode.unknown,
      };
}
