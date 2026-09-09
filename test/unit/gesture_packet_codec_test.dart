import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/codec/gesture_packet_codec.dart';

void main() {
  group('GesturePacketCodec.decode', () {
    test('decodes a valid little-endian packet (SRS Table III-2 example)',
        () {
      // word_id 0x1234, confidence 0x5A = 90, timestamp_ms 0x3E8 = 1000
      final bytes = Uint8List.fromList([0x34, 0x12, 0x5A, 0xE8, 0x03, 0x00, 0x00]);
      final packet = GesturePacketCodec.decode(
        bytes,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1500),
      );

      expect(packet.wordId, 0x1234);
      expect(packet.confidence, 90);
      expect(packet.gloveTimestampMs, 1000);
      expect(packet.latencyMs, 500);
    });

    test('decodes max values without overflow', () {
      final bytes = Uint8List.fromList([0xFF, 0xFF, 0x64, 0xFF, 0xFF, 0xFF, 0xFF]);
      final packet = GesturePacketCodec.decode(bytes);

      expect(packet.wordId, 0xFFFF);
      expect(packet.confidence, 100);
      expect(packet.gloveTimestampMs, 0xFFFFFFFF);
    });

    test('decodes minimum values', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final packet = GesturePacketCodec.decode(bytes);

      expect(packet.wordId, 0);
      expect(packet.confidence, 0);
      expect(packet.gloveTimestampMs, 0);
    });

    test('clamps out-of-range confidence to 0–100', () {
      final base = Uint8List.fromList([0x01, 0x00, 0xC8, 0x00, 0x00, 0x00, 0x00]);
      final packet = GesturePacketCodec.decode(base);
      expect(packet.confidence, 100); // 200 clamped
    });

    test('throws FormatException on truncated payload', () {
      final bytes = Uint8List.fromList([0x34, 0x12, 0x5A, 0xE8, 0x03, 0x00]);
      expect(() => GesturePacketCodec.decode(bytes), throwsFormatException);
    });

    test('throws FormatException on oversized payload', () {
      final bytes = Uint8List.fromList(
          [0x34, 0x12, 0x5A, 0xE8, 0x03, 0x00, 0x00, 0x00]);
      expect(() => GesturePacketCodec.decode(bytes), throwsFormatException);
    });

    test('throws FormatException on empty payload', () {
      expect(() => GesturePacketCodec.decode(Uint8List(0)),
          throwsFormatException);
    });
  });
}
