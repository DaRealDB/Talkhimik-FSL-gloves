import 'package:meta/meta.dart';

import '../../core/constants/confidence.dart';

/// Who produced a transcript bubble (FR-3, FR-7).
enum TranscriptKind {
  /// Recognized sign from the glove (or mock).
  signed,

  /// Text typed by the hearing partner in the reply panel.
  partner,

  /// App-generated notices (e.g. "connection lost").
  system,
}

/// One bubble in the conversation transcript (SRS FR-3, FR-4, FR-7).
@immutable
class TranscriptEntry {
  const TranscriptEntry({
    required this.id,
    required this.kind,
    required this.filipino,
    required this.english,
    this.confidence,
    this.confidenceLevel,
    this.corrected = false,
    this.originalWordId,
    this.source = 'glove',
  });

  /// Monotonic id within the transcript; also the tap target for FR-5.
  final int id;

  final TranscriptKind kind;

  /// Both language variants are always stored so the FR-15 language toggle
  /// re-renders existing bubbles without losing anything.
  final String filipino;
  final String english;

  /// Present for [TranscriptKind.signed] entries only.
  final int? confidence;
  final ConfidenceLevel? confidenceLevel;

  /// True when the signer corrected this bubble via quick rephrase (FR-5).
  final bool corrected;

  /// The glove's original word id before a correction was applied.
  final int? originalWordId;

  /// Provenance for logging: glove | mock | correction | partner.
  final String source;

  String textFor(String language) => language == 'en' ? english : filipino;
}
