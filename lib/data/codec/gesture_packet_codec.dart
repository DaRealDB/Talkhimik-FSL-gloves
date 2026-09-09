import 'dart:typed_data';

import '../../core/constants/gatt_ids.dart';
import '../../domain/models/gesture_result.dart';

/// Strict little-endian decoder for the 7-byte gesture result packet
/// (SRS Table III-2).
///
/// The codec validates structure only: length must be exactly
/// [GattIds.gesturePacketLength], confidence is clamped to 0–100. Unknown
/// word_ids are the vocabulary layer's concern, not the codec's.
class GesturePacketCodec {
  GesturePacketCodec._();

  /// Decodes one NOTIFY payload. Throws [FormatException] when the payload
  /// is not exactly 7 bytes.
  static GestureResultPacket decode(Uint8List bytes, {DateTime? receivedAt}) {
    if (bytes.length != GattIds.gesturePacketLength) {
      throw FormatException(
        'Gesture packet must be ${GattIds.gesturePacketLength} bytes '
        '(word_id u16 + confidence u8 + timestamp_ms u32), '
        'got ${bytes.length}',
      );
    }

    final data = ByteData.sublistView(bytes);
    return GestureResultPacket(
      wordId: data.getUint16(0, Endian.little),
      confidence: data.getUint8(2).clamp(0, 100),
      gloveTimestampMs: data.getUint32(3, Endian.little),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }
}
