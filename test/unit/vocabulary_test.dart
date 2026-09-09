import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/data/vocab/default_vocabulary_repository.dart';
import 'package:talkhimik_app/domain/vocab/fsl_vocabulary.dart';
import 'package:talkhimik_app/domain/vocab/vocab_entry.dart';

void main() {
  group('fsl_vocabulary table', () {
    test('has exactly 28 letters with contiguous unique ids 1..28', () {
      final letters =
          fslVocabulary.where((e) => e.category == VocabCategory.letter).toList();

      expect(letters, hasLength(28));
      final ids = letters.map((e) => e.wordId).toList()..sort();
      expect(ids, List<int>.generate(28, (i) => i + 1));
    });

    test('contains the Filipino-specific letters Ñ and NG', () {
      final letters =
          fslVocabulary.where((e) => e.category == VocabCategory.letter);
      expect(letters.any((e) => e.filipino == 'Ñ'), isTrue);
      expect(letters.any((e) => e.filipino == 'NG'), isTrue);
    });

    test('all word ids are unique across the whole table', () {
      final ids = fslVocabulary.map((e) => e.wordId).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('has at least 15 curated phrases (DR-2 target)', () {
      final phrases =
          fslVocabulary.where((e) => e.category == VocabCategory.phrase);
      expect(phrases.length, greaterThanOrEqualTo(15));
    });

    test('every entry has non-empty Filipino and English text', () {
      for (final e in fslVocabulary) {
        expect(e.filipino.trim(), isNotEmpty, reason: 'wordId ${e.wordId}');
        expect(e.english.trim(), isNotEmpty, reason: 'wordId ${e.wordId}');
      }
    });

    test('letter and phrase id ranges do not overlap', () {
      final letters =
          fslVocabulary.where((e) => e.category == VocabCategory.letter);
      final phrases =
          fslVocabulary.where((e) => e.category == VocabCategory.phrase);
      expect(phrases.every((p) => p.wordId >= 100), isTrue);
      expect(letters.every((l) => l.wordId < 100), isTrue);
    });
  });

  group('DefaultVocabularyRepository', () {
    final repo = DefaultVocabularyRepository();

    test('lookup returns the mapped entry', () {
      final a = repo.lookup(1)!;
      expect(a.filipino, 'A');
      expect(a.english, 'A');

      final kumusta = repo.lookup(100)!;
      expect(kumusta.filipino, 'Kumusta');
      expect(kumusta.english, 'How are you?');
    });

    test('lookup returns null for unknown ids', () {
      expect(repo.lookup(9999), isNull);
    });

    test('fallbackAlternatives returns 3 same-category alternatives '
        'excluding the id itself', () {
      final alts = repo.fallbackAlternatives(10); // J
      expect(alts, hasLength(3));
      expect(alts.map((a) => a.wordId), isNot(contains(10)));
      expect(
        repo.lookup(alts.first.wordId)!.category,
        VocabCategory.letter,
      );
    });

    test('fallbackAlternatives on a phrase stays within phrases', () {
      final alts = repo.fallbackAlternatives(100); // Kumusta
      expect(alts, hasLength(3));
      expect(
        alts.every((a) =>
            repo.lookup(a.wordId)!.category == VocabCategory.phrase),
        isTrue,
      );
    });

    test('fallbackAlternatives returns empty for unknown ids', () {
      expect(repo.fallbackAlternatives(9999), isEmpty);
    });
  });
}
