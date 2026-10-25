import 'dart:typed_data';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/telemetry_packet.dart';

/// Strict little-endian decoder for the 29-byte TELEMETRY frame
/// (Code Reference §5.2).
///
/// Layout: u8 hand · u16 seq · u8 flex[5] angles · i16 roll/pitch/yaw ×10 ·
/// u16 raw ADC[5] · u32 calibration_id · u8 quality.
class TelemetryPacketCodec {
  TelemetryPacketCodec._();

  /// Decodes one NOTIFY payload. Throws [FormatException] when the payload
  /// is not exactly [GattIds.telemetryPacketLength] bytes.
  static TelemetryPacket decode(Uint8List bytes, {DateTime? receivedAt}) {
    if (bytes.length != GattIds.telemetryPacketLength) {
      throw FormatException(
        'Telemetry packet must be ${GattIds.telemetryPacketLength} bytes '
        '(Code Reference §5.2), got ${bytes.length}',
      );
    }

    final data = ByteData.sublistView(bytes);
    return TelemetryPacket(
      hand: _handFromCode(data.getUint8(0)),
      seq: data.getUint16(1, Endian.little),
      angles: [for (var i = 0; i < 5; i++) data.getUint8(3 + i)],
      rollDeg: data.getInt16(8, Endian.little) / 10,
      pitchDeg: data.getInt16(10, Endian.little) / 10,
      yawDeg: data.getInt16(12, Endian.little) / 10,
      rawAdc: [for (var i = 0; i < 5; i++) data.getUint16(14 + i * 2, Endian.little)],
      calibrationId: data.getUint32(24, Endian.little),
      quality: data.getUint8(28),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  static GloveHand _handFromCode(int code) =>
      code == 0 ? GloveHand.left : GloveHand.right;
}
