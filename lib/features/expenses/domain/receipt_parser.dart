/// Parses raw OCR text from a receipt photo into structured fields.
///
/// Deliberately a pure, dependency-free class (no ML Kit, no Flutter) so the
/// parsing heuristics are unit-testable against known OCR output strings
/// without needing a camera, an image, or the ML Kit plugin at all. ML Kit
/// only produces the raw text; everything from here on is ordinary string
/// processing that deserves the same test rigor as the financial calculators.
library;

class ParsedReceipt {
  final String? merchantName;
  final double? totalAmount;
  final DateTime? date;
  final double confidence;

  const ParsedReceipt({
    this.merchantName,
    this.totalAmount,
    this.date,
    required this.confidence,
  });

  bool get hasUsableData => merchantName != null || totalAmount != null;
}

abstract final class ReceiptParser {
  static final _currencyPattern = RegExp(r'[\$£€]?\s?(\d{1,3}(?:[,.]\d{3})*(?:[.,]\d{2}))');

  static final _totalKeywords = [
    'total', 'amount due', 'balance due', 'grand total', 'amount', 'balance',
  ];

  // Explicitly excluded from being mistaken for the total — receipts often
  // show subtotal/tax lines with larger or similarly-formatted numbers.
  static final _excludedKeywords = [
    'subtotal', 'sub total', 'sub-total', 'tax', 'change', 'cash', 'card',
    'visa', 'mastercard', 'tip', 'gratuity',
  ];

  static final _datePatterns = [
    // MM/DD/YYYY or DD/MM/YYYY or MM-DD-YYYY etc.
    RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'),
    // YYYY-MM-DD (ISO-ish)
    RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})'),
    // "Jan 15, 2026" / "15 Jan 2026"
    RegExp(
      r'(\d{1,2})?\s?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s?,?\s?(\d{1,2})?,?\s?(\d{4})',
      caseSensitive: false,
    ),
  ];

  static const _monthAbbreviations = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static ParsedReceipt parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ParsedReceipt(confidence: 0);
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchantName = _extractMerchantName(lines);
    final totalAmount = _extractTotalAmount(lines);
    final date = _extractDate(rawText);

    // Simple confidence heuristic: more fields found = higher confidence.
    // This is surfaced to the user as "review before saving", never used to
    // silently auto-submit — OCR on receipts is never reliable enough for that.
    int fieldsFound = 0;
    if (merchantName != null) fieldsFound++;
    if (totalAmount != null) fieldsFound++;
    if (date != null) fieldsFound++;
    final confidence = fieldsFound / 3.0;

    return ParsedReceipt(
      merchantName: merchantName,
      totalAmount: totalAmount,
      date: date,
      confidence: confidence,
    );
  }

  /// Heuristic: the merchant name is almost always the first substantial
  /// line of a receipt, before address/phone/date lines begin. We skip
  /// lines that look like addresses, phone numbers, or pure numbers.
  static String? _extractMerchantName(List<String> lines) {
    for (final line in lines.take(5)) {
      if (line.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(line)) continue; // pure number
      if (RegExp(r'\d{3}[-.\s]?\d{3}[-.\s]?\d{4}').hasMatch(line)) continue; // phone
      if (RegExp(r'^\d+\s+\w+\s+(st|street|ave|avenue|rd|road|blvd)', caseSensitive: false)
          .hasMatch(line)) {
        continue; // street address
      }
      if (_currencyPattern.hasMatch(line) && line.length < 15) continue; // isolated price line

      return line;
    }
    return null;
  }

  /// Finds the total amount by preferring lines with a "total"-style
  /// keyword and no excluded keyword (subtotal/tax/change), falling back to
  /// the largest currency-formatted number anywhere on the receipt.
  static double? _extractTotalAmount(List<String> lines) {
    double? keywordMatch;
    double? largestAmount;

    for (final line in lines) {
      final lower = line.toLowerCase();
      final matches = _currencyPattern.allMatches(line);
      if (matches.isEmpty) continue;

      for (final match in matches) {
        final value = _parseAmount(match.group(1)!);
        if (value == null) continue;

        if (largestAmount == null || value > largestAmount) {
          largestAmount = value;
        }

        final hasExcluded = _excludedKeywords.any((k) => lower.contains(k));
        final hasTotal = _totalKeywords.any((k) => lower.contains(k));

        if (hasTotal && !hasExcluded) {
          // Prefer the last such match — receipts often list "Total" once,
          // near the bottom, after tax/subtotal lines earlier.
          keywordMatch = value;
        }
      }
    }

    return keywordMatch ?? largestAmount;
  }

  static double? _parseAmount(String raw) {
    // Normalize "1,234.56" and "1.234,56" style formatting to a plain double.
    final cleaned = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;

    // If both separators are present, assume the last one is the decimal
    // point and the other is a thousands separator.
    if (cleaned.contains(',') && cleaned.contains('.')) {
      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');
      final normalized = lastDot > lastComma
          ? cleaned.replaceAll(',', '')
          : cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    // Only a comma present — likely a decimal separator (European style)
    // if exactly two digits follow it, otherwise a thousands separator.
    if (cleaned.contains(',') && !cleaned.contains('.')) {
      final parts = cleaned.split(',');
      if (parts.last.length == 2) {
        return double.tryParse('${parts.sublist(0, parts.length - 1).join('')}.${parts.last}');
      }
      return double.tryParse(cleaned.replaceAll(',', ''));
    }

    return double.tryParse(cleaned);
  }

  static DateTime? _extractDate(String rawText) {
    // Numeric formats first (MM/DD/YYYY, YYYY-MM-DD, etc.)
    for (final pattern in _datePatterns.take(2)) {
      final match = pattern.firstMatch(rawText);
      if (match == null) continue;

      final parsed = _tryBuildDateFromNumericMatch(match, pattern == _datePatterns[1]);
      if (parsed != null) return parsed;
    }

    // Written-month format (e.g. "Jan 15, 2026")
    final monthMatch = _datePatterns[2].firstMatch(rawText);
    if (monthMatch != null) {
      final parsed = _tryBuildDateFromMonthMatch(monthMatch);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static DateTime? _tryBuildDateFromNumericMatch(RegExpMatch match, bool isIsoStyle) {
    try {
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);
      final c = int.parse(match.group(3)!);

      if (isIsoStyle) {
        // YYYY-MM-DD
        return _validOrNull(a, b, c);
      }

      // Ambiguous MM/DD/YYYY vs DD/MM/YYYY — prefer MM/DD (US receipts are
      // the common case for this app's primary market) but fall back to
      // DD/MM if the "month" value is out of range.
      final year = c < 100 ? 2000 + c : c;
      if (a <= 12) {
        final candidate = _validOrNull(year, a, b);
        if (candidate != null) return candidate;
      }
      return _validOrNull(year, b, a);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _tryBuildDateFromMonthMatch(RegExpMatch match) {
    try {
      final monthAbbr = match.group(2)!.toLowerCase().substring(0, 3);
      final month = _monthAbbreviations[monthAbbr];
      if (month == null) return null;

      final dayBefore = match.group(1);
      final dayAfter = match.group(3);
      final day = int.tryParse(dayBefore ?? dayAfter ?? '');
      final year = int.tryParse(match.group(4)!);

      if (day == null || year == null) return null;
      return _validOrNull(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _validOrNull(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2000 || year > DateTime.now().year + 1) return null;
    try {
      final date = DateTime(year, month, day);
      // Reject dates in the future beyond a small buffer (clock skew) —
      // a receipt from next year is almost certainly a misparse.
      if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
      return date;
    } catch (_) {
      return null;
    }
  }
}
