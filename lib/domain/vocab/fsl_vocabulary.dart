import 'vocab_entry.dart';

/// THE editable vocabulary table — the shared word_id contract between the
/// glove firmware (ESP32-S3 TFLite Micro output) and this app.
///
/// Rules (enforced by test/unit/vocabulary_test.dart):
///  * Letter ids are 1..28, contiguous and unique (28-letter FSL alphabet:
///    A–Z plus Ñ and NG).
///  * Phrase ids start at 100.
///  * Every word_id is unique across the whole table.
///
/// The firmware keeps its own copy of this id list; changing an id here
/// requires a matching firmware change.
///
/// The phrase list is a PLACEHOLDER pending adviser sign-off
/// (SRS open item 4, DR-2: 15–20 curated phrases).
const List<VocabEntry> fslVocabulary = [
  // ---- Letters (ids 1..28, FSL alphabet order) ----
  VocabEntry(wordId: 1, filipino: 'A', english: 'A', category: VocabCategory.letter),
  VocabEntry(wordId: 2, filipino: 'B', english: 'B', category: VocabCategory.letter),
  VocabEntry(wordId: 3, filipino: 'C', english: 'C', category: VocabCategory.letter),
  VocabEntry(wordId: 4, filipino: 'D', english: 'D', category: VocabCategory.letter),
  VocabEntry(wordId: 5, filipino: 'E', english: 'E', category: VocabCategory.letter),
  VocabEntry(wordId: 6, filipino: 'F', english: 'F', category: VocabCategory.letter),
  VocabEntry(wordId: 7, filipino: 'G', english: 'G', category: VocabCategory.letter),
  VocabEntry(wordId: 8, filipino: 'H', english: 'H', category: VocabCategory.letter),
  VocabEntry(wordId: 9, filipino: 'I', english: 'I', category: VocabCategory.letter),
  VocabEntry(wordId: 10, filipino: 'J', english: 'J', category: VocabCategory.letter),
  VocabEntry(wordId: 11, filipino: 'K', english: 'K', category: VocabCategory.letter),
  VocabEntry(wordId: 12, filipino: 'L', english: 'L', category: VocabCategory.letter),
  VocabEntry(wordId: 13, filipino: 'M', english: 'M', category: VocabCategory.letter),
  VocabEntry(wordId: 14, filipino: 'N', english: 'N', category: VocabCategory.letter),
  VocabEntry(wordId: 15, filipino: 'Ñ', english: 'Ñ', category: VocabCategory.letter),
  VocabEntry(wordId: 16, filipino: 'NG', english: 'NG', category: VocabCategory.letter),
  VocabEntry(wordId: 17, filipino: 'O', english: 'O', category: VocabCategory.letter),
  VocabEntry(wordId: 18, filipino: 'P', english: 'P', category: VocabCategory.letter),
  VocabEntry(wordId: 19, filipino: 'Q', english: 'Q', category: VocabCategory.letter),
  VocabEntry(wordId: 20, filipino: 'R', english: 'R', category: VocabCategory.letter),
  VocabEntry(wordId: 21, filipino: 'S', english: 'S', category: VocabCategory.letter),
  VocabEntry(wordId: 22, filipino: 'T', english: 'T', category: VocabCategory.letter),
  VocabEntry(wordId: 23, filipino: 'U', english: 'U', category: VocabCategory.letter),
  VocabEntry(wordId: 24, filipino: 'V', english: 'V', category: VocabCategory.letter),
  VocabEntry(wordId: 25, filipino: 'W', english: 'W', category: VocabCategory.letter),
  VocabEntry(wordId: 26, filipino: 'X', english: 'X', category: VocabCategory.letter),
  VocabEntry(wordId: 27, filipino: 'Y', english: 'Y', category: VocabCategory.letter),
  VocabEntry(wordId: 28, filipino: 'Z', english: 'Z', category: VocabCategory.letter),

  // ---- Curated phrases (ids 100+; placeholder list — see note above) ----
  VocabEntry(wordId: 100, filipino: 'Kumusta', english: 'How are you?', category: VocabCategory.phrase),
  VocabEntry(wordId: 101, filipino: 'Magandang umaga', english: 'Good morning', category: VocabCategory.phrase),
  VocabEntry(wordId: 102, filipino: 'Magandang hapon', english: 'Good afternoon', category: VocabCategory.phrase),
  VocabEntry(wordId: 103, filipino: 'Magandang gabi', english: 'Good evening', category: VocabCategory.phrase),
  VocabEntry(wordId: 104, filipino: 'Salamat', english: 'Thank you', category: VocabCategory.phrase),
  VocabEntry(wordId: 105, filipino: 'Walang anuman', english: "You're welcome", category: VocabCategory.phrase),
  VocabEntry(wordId: 106, filipino: 'Paalam', english: 'Goodbye', category: VocabCategory.phrase),
  VocabEntry(wordId: 107, filipino: 'Oo', english: 'Yes', category: VocabCategory.phrase),
  VocabEntry(wordId: 108, filipino: 'Hindi', english: 'No', category: VocabCategory.phrase),
  VocabEntry(wordId: 109, filipino: 'Pasensya na', english: 'Sorry', category: VocabCategory.phrase),
  VocabEntry(wordId: 110, filipino: 'Tulong', english: 'Help', category: VocabCategory.phrase),
  VocabEntry(wordId: 111, filipino: 'Mahal kita', english: 'I love you', category: VocabCategory.phrase),
  VocabEntry(wordId: 112, filipino: 'Ano ang pangalan mo?', english: 'What is your name?', category: VocabCategory.phrase),
  VocabEntry(wordId: 113, filipino: 'Saan ang palikuran?', english: 'Where is the restroom?', category: VocabCategory.phrase),
  VocabEntry(wordId: 114, filipino: 'Gutom ako', english: 'I am hungry', category: VocabCategory.phrase),
  VocabEntry(wordId: 115, filipino: 'Uhaw ako', english: 'I am thirsty', category: VocabCategory.phrase),
  VocabEntry(wordId: 116, filipino: 'Magkano?', english: 'How much?', category: VocabCategory.phrase),
];
