/// Minimal, correct CSV writer following RFC 4180 quoting rules.
/// A dedicated `csv` package dependency isn't justified for this narrow,
/// well-understood use case — hand-rolling it here keeps the dependency
/// surface smaller and the logic auditable in one place.
library;

abstract final class CsvExporter {
  static String build(List<String> headers, List<List<Object?>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeField).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeField).join(','));
    }
    return buffer.toString();
  }

  static String _escapeField(Object? value) {
    final str = value?.toString() ?? '';
    // RFC 4180: fields containing comma, quote, or newline must be quoted,
    // and embedded quotes are escaped by doubling them.
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }
}
