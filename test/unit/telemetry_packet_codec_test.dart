import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/codec/telemetry_packet_codec.dart';
import 'package:talkhimik_app/domain/models/telemetry_packet.dart';

void main() {
  /// Builds a 29-byte frame (Code Reference §5.2) with every field set.
  Uint8List frame() {
    final bytes = Uint8List(29);
    final data = ByteData.sublistView(bytes);
    data.setUint8(0, 1); // right hand
    data.setUint16(1, 0x1234, Endian.little);
    for (var i = 0; i < 5; i++) {
      data.setUint8(3 + i, 10 * (i + 1)); // angles 10..50
    }
    data.setInt16(8, -450, Endian.little); // roll -45.0°
    data.setInt16(10, 300, Endian.little); // pitch 30.0°
    data.setInt16(12, 0, Endian.little);
    for (var i = 0; i < 5; i++) {
      data.setUint16(14 + i * 2, 100 * (i + 1), Endian.little);
    }
    data.setUint32(24, 7, Endian.little);
    data.setUint8(28, 0x21); // bit0 valid, bit5 weak span
    return bytes;
  }

  test('decodes the full 29-byte firmware TELEMETRY frame', () {
    final receivedAt = DateTime.fromMillisecondsSinceEpoch(1000);
    final packet = TelemetryPacketCodec.decode(frame(), receivedAt: receivedAt);

    expect(packet.hand, GloveHand.right);
    expect(packet.seq, 0x1234);
    expect(packet.angles, [10, 20, 30, 40, 50]);
    expect(packet.rollDeg, -45.0);
    expect(packet.pitchDeg, 30.0);
    expect(packet.yawDeg, 0.0);
    expect(packet.rawAdc, [100, 200, 300, 400, 500]);
    expect(packet.calibrationId, 7);
    expect(packet.validMask, 1);
    expect(packet.anyWeakSpan, isTrue);
    expect(packet.receivedAt, receivedAt);
  });

  test('hand 0 maps to left; any other code to right', () {
    final bytes = frame();
    bytes[0] = 0;
    expect(TelemetryPacketCodec.decode(bytes).hand, GloveHand.left);

    bytes[0] = 2;
    expect(TelemetryPacketCodec.decode(bytes).hand, GloveHand.right);
  });

  test('quality byte without the weak bit reports no weak span', () {
    final bytes = frame();
    bytes[28] = 0x1F;
    final packet = TelemetryPacketCodec.decode(bytes);
    expect(packet.validMask, 0x1F);
    expect(packet.anyWeakSpan, isFalse);
  });

  test('rejects payloads that are not 29 bytes', () {
    expect(
      () => TelemetryPacketCodec.decode(Uint8List(28)),
      throwsFormatException,
    );
    expect(
      () => TelemetryPacketCodec.decode(Uint8List(30)),
      throwsFormatException,
    );
  });
}
