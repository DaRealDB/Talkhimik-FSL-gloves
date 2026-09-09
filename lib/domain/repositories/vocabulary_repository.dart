import '../models/gesture_result.dart';
import '../vocab/vocab_entry.dart';

/// Maps glove word_ids to Filipino/English text (SRS FR-1, C-S2).
///
/// The default implementation reads the const table in
/// `domain/vocab/fsl_vocabulary.dart`; swap the implementation if the team
/// later moves the table to an asset file.
abstract interface class VocabularyRepository {
  /// Returns null for ids outside the table; callers render a placeholder.
  VocabEntry? lookup(int wordId);

  List<VocabEntry> get letters;
  List<VocabEntry> get phrases;

  /// Top-3 alternatives for quick rephrase (FR-5) when the glove sent none:
  /// the closest same-category ids (letters for letters, phrases for
  /// phrases), excluding the id itself.
  List<AlternativePrediction> fallbackAlternatives(int wordId);
}
