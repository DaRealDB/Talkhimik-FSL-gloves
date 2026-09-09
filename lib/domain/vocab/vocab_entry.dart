import 'package:meta/meta.dart';

/// Where a vocabulary entry comes from (drives FR-5 fallback alternatives).
enum VocabCategory { letter, phrase }

/// One row of the word_id ↔ text contract shared with the glove firmware.
@immutable
class VocabEntry {
  const VocabEntry({
    required this.wordId,
    required this.filipino,
    required this.english,
    required this.category,
  });

  /// uint16 vocabulary id — the value the glove sends over BLE.
  final int wordId;

  final String filipino;
  final String english;
  final VocabCategory category;
}
