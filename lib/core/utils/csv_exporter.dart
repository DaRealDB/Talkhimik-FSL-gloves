/// Minimal RFC 4180 CSV writer.
///
/// Hand-rolled on purpose: the `csv` pub package is unmaintained and the
/// rules here are ~15 lines that the panel can verify directly.
/// Fields containing a comma, double quote, or line break are quoted and
/// embedded quotes are doubled.
class CsvExporter {
  CsvExporter._();

  static String toCsv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.write(row.map(_field).join(','));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _field(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
