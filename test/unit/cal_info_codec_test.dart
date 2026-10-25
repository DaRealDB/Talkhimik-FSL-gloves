import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/codec/cal_info_codec.dart';

void main() {
  /// Builds a 104-byte CAL_INFO table (Code Reference §5.5).
  Uint8List frame() {
    final bytes = Uint8List(104);
    final data = ByteData.sublistView(bytes);
    data.setUint8(0, 0x1F); // all five fingers valid
    data.setUint8(1, 0x04); // ring finger span was weak
    data.setUint32(2, 3, Endian.little);
    for (var i = 0; i < 5; i++) {
      data.setFloat32(6 + i * 4, 30000.0, Endian.little); // flat ohm
      data.setFloat32(26 + i * 4, 60000.0, Endian.little); // bent90 ohm
      data.setUint16(46 + i * 2, 500, Endian.little); // flat adc
      data.setUint16(56 + i * 2, 1500, Endian.little); // bent90 adc
      data.setFloat32(66 + i * 4, 10000.0, Endian.little); // R_DIV
      data.setUint16(86 + i * 2, 1000, Endian.little); // span counts
    }
    const fw = '1.2.0\x00\x00\x00';
    for (var i = 0; i < 8; i++) {
      data.setUint8(96 + i, fw.codeUnitAt(i));
    }
    return bytes;
  }

  test('decodes the full 104-byte firmware CAL_INFO table', () {
    final packet = CalInfoCodec.decode(frame());

    expect(packet.validMask, 0x1F);
    expect(packet.weakMask, 0x04);
    expect(packet.calibrationId, 3);
    expect(packet.flatOhm, everyElement(closeTo(30000.0, 0.01)));
    expect(packet.bent90Ohm, everyElement(closeTo(60000.0, 0.01)));
    expect(packet.flatAdc, everyElement(500));
    expect(packet.bent90Adc, everyElement(1500));
    expect(packet.rDiv, everyElement(closeTo(10000.0, 0.01)));
    expect(packet.spanCounts, everyElement(1000));
    expect(packet.firmwareVersion, '1.2.0'); // zero-padding trimmed
  });

  test('rejects payloads that are not 104 bytes', () {
    expect(
      () => CalInfoCodec.decode(Uint8List(103)),
      throwsFormatException,
    );
    expect(
      () => CalInfoCodec.decode(Uint8List(105)),
      throwsFormatException,
    );
  });
}
