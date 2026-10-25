import 'dart:typed_data';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/cal_info_packet.dart';

/// Strict little-endian decoder for the 104-byte CAL_INFO table
/// (Code Reference §5.5).
///
/// Layout: u8 valid · u8 weak · u32 calibration_id · float flat_ohm[5] ·
/// float bent90_ohm[5] · u16 flat_adc[5] · u16 bent90_adc[5] ·
/// float R_DIV[5] · u16 span[5] · u8 fw_version[8].
class CalInfoCodec {
  CalInfoCodec._();

  /// Decodes one READ/NOTIFY payload. Throws [FormatException] when the
  /// payload is not exactly [GattIds.calInfoPacketLength] bytes.
  static CalInfoPacket decode(Uint8List bytes) {
    if (bytes.length != GattIds.calInfoPacketLength) {
      throw FormatException(
        'CAL_INFO must be ${GattIds.calInfoPacketLength} bytes '
        '(Code Reference §5.5), got ${bytes.length}',
      );
    }

    final data = ByteData.sublistView(bytes);
    return CalInfoPacket(
      validMask: data.getUint8(0),
      weakMask: data.getUint8(1),
      calibrationId: data.getUint32(2, Endian.little),
      flatOhm: [for (var i = 0; i < 5; i++) data.getFloat32(6 + i * 4, Endian.little)],
      bent90Ohm: [
        for (var i = 0; i < 5; i++) data.getFloat32(26 + i * 4, Endian.little),
      ],
      flatAdc: [
        for (var i = 0; i < 5; i++) data.getUint16(46 + i * 2, Endian.little),
      ],
      bent90Adc: [
        for (var i = 0; i < 5; i++) data.getUint16(56 + i * 2, Endian.little),
      ],
      rDiv: [for (var i = 0; i < 5; i++) data.getFloat32(66 + i * 4, Endian.little)],
      spanCounts: [
        for (var i = 0; i < 5; i++) data.getUint16(86 + i * 2, Endian.little),
      ],
      firmwareVersion: _ascii(
          Uint8List.sublistView(bytes, 96, 104)),
    );
  }

  /// Zero-padded ASCII → trimmed string.
  static String _ascii(Uint8List bytes) =>
      String.fromCharCodes(bytes).replaceAll('\x00', '').trim();
}
