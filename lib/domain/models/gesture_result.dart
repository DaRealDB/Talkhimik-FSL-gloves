import 'package:meta/meta.dart';

/// An alternative prediction offered for quick rephrase (FR-5).
@immutable
class AlternativePrediction {
  const AlternativePrediction({required this.wordId, required this.confidence});

  final int wordId;
  final int confidence; // 0–100
}

/// One decoded gesture result from the glove.
///
/// Packet contract per SRS Table III-2 (7 bytes, little-endian):
/// word_id u16 @0, confidence u8 @2, timestamp_ms u32 @3.
@immutable
class GestureResultPacket {
  const GestureResultPacket({
    required this.wordId,
    required this.confidence,
    required this.gloveTimestampMs,
    required this.receivedAt,
    this.alternatives = const [],
    this.source,
    this.modelVersion,
  });

  /// Vocabulary ID; the app maps it to Filipino/English text (FR-1).
  final int wordId;

  /// Glove confidence, 0–100.
  final int confidence;

  /// Glove millis at gesture completion.
  final int gloveTimestampMs;

  /// Phone clock at NOTIFY receipt (set by the connection implementation).
  final DateTime receivedAt;

  /// Top-3 alternative predictions for FR-5. Empty for the real glove v1;
  /// the mock supplies them and the vocabulary repository has a fallback.
  final List<AlternativePrediction> alternatives;

  /// Provenance override for phone-side recognition ('phone-threshold',
  /// 'phone-tflite'); null for glove/mock packets, where the transcript
  /// derives source from the connection kind.
  final String? source;

  /// Model version that produced this event (truthful FR-10 export);
  /// null = no model (glove packets, mock).
  final String? modelVersion;

  /// End-to-end latency estimate (NFR-1 target: ≤ 500 ms).
  ///
  /// Caveat for Chapter 3: glove and phone clocks are unsynchronized, so
  /// this is an approximate measure, not a true round-trip clock reading.
  int get latencyMs => receivedAt.millisecondsSinceEpoch - gloveTimestampMs;
}
