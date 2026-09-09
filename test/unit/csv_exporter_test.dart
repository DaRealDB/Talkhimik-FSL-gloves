import 'package:flutter_test/flutter_test.dart';
import 'package:talkhimik_app/core/utils/csv_exporter.dart';

void main() {
  group('CsvExporter.toCsv', () {
    test('writes plain rows with CRLF line endings', () {
      final csv = CsvExporter.toCsv([
        ['wordId', 'filipinoText', 'confidence'],
        ['1', 'A', '95'],
      ]);
      expect(csv, 'wordId,filipinoText,confidence\r\n1,A,95\r\n');
    });

    test('quotes fields containing commas', () {
      final csv = CsvExporter.toCsv([
        ['100', 'Kumusta, kaibigan', '95'],
      ]);
      expect(csv, '100,"Kumusta, kaibigan",95\r\n');
    });

    test('doubles embedded double quotes inside quoted fields', () {
      final csv = CsvExporter.toCsv([
        ['1', 'Sabi nya: "Hello"', '95'],
      ]);
      expect(csv, '1,"Sabi nya: ""Hello""",95\r\n');
    });

    test('quotes fields containing newlines', () {
      final csv = CsvExporter.toCsv([
        ['1', 'line1\nline2', '95'],
      ]);
      expect(csv, '1,"line1\nline2",95\r\n');
    });

    test('handles empty rows and empty cells', () {
      final csv = CsvExporter.toCsv([
        <String>[],
        ['', 'x'],
      ]);
      expect(csv, '\r\n,x\r\n');
    });
  });
}
