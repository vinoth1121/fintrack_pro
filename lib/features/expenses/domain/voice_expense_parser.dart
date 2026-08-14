/// Parses natural-language spoken expense descriptions into structured
/// fields. Pure, dependency-free (no speech_to_text, no Flutter) so the
/// parsing heuristics are independently testable against known transcript
/// strings — mirroring the same architecture used for ReceiptParser.
///
/// Handles phrasings like:
///   "I spent forty five dollars at Starbucks"
///   "Spent 12.50 on lunch"
///   "45 dollars for groceries at Whole Foods"
///   "Paid twenty at the gas station"
library;

class ParsedVoiceExpense {
  final double? amount;
  final String? merchant;
  final String? categoryHint;
  final double confidence;

  const ParsedVoiceExpense({
    this.amount,
    this.merchant,
    this.categoryHint,
    required this.confidence,
  });

  bool get hasUsableData => amount != null;
}

abstract final class VoiceExpenseParser {
  // Numeric amount: "45", "45.50", "$45", "45 dollars", "45 bucks"
  static final _numericAmountPattern = RegExp(
    r'\$?\s?(\d+(?:\.\d{1,2})?)\s?(?:dollars?|bucks?)?',
    caseSensitive: false,
  );

  // "at <merchant>" or "from <merchant>" — the most reliable merchant signal
  static final _merchantAtPattern = RegExp(
    r"\b(?:at|from)\s+([A-Z][a-zA-Z0-9&'\s]{1,40}?)(?:\s+(?:for|today|yesterday|this|on)\b|[.,!?]|$)",
  );

  /// Common spoken-expense category keywords mapped to the app's default
  /// expense category ids (see DefaultCategories.expense in expense_entity.dart).
  static const _categoryKeywords = {
    'food': 'food', 'lunch': 'food', 'dinner': 'food', 'breakfast': 'food',
    'coffee': 'food', 'groceries': 'food', 'restaurant': 'food',
    'gas': 'transport', 'fuel': 'transport', 'uber': 'transport',
    'taxi': 'transport', 'parking': 'transport', 'transport': 'transport',
    'shopping': 'shopping', 'clothes': 'shopping', 'clothing': 'shopping',
    'movie': 'entertainment', 'movies': 'entertainment', 'cinema': 'entertainment',
    'entertainment': 'entertainment', 'games': 'entertainment',
    'electricity': 'utilities', 'water bill': 'utilities', 'internet': 'utilities',
    'utilities': 'utilities', 'phone bill': 'utilities',
    'doctor': 'health', 'pharmacy': 'health', 'medicine': 'health', 'health': 'health',
    'books': 'education', 'course': 'education', 'tuition': 'education',
    'rent': 'rent', 'mortgage': 'rent',
    'flight': 'travel', 'hotel': 'travel', 'travel': 'travel', 'vacation': 'travel',
  };

  static ParsedVoiceExpense parse(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const ParsedVoiceExpense(confidence: 0);
    }

    final amount = _extractAmount(text);
    final merchant = _extractMerchant(text);
    final categoryHint = _extractCategoryHint(text);

    int fieldsFound = 0;
    if (amount != null) fieldsFound++;
    if (merchant != null) fieldsFound++;
    if (categoryHint != null) fieldsFound++;

    // Amount is the load-bearing field — without it, there's nothing to
    // pre-fill regardless of what else was understood.
    final confidence = amount == null ? 0.0 : (0.5 + (fieldsFound - 1) * 0.25).clamp(0.0, 1.0);

    return ParsedVoiceExpense(
      amount: amount,
      merchant: merchant,
      categoryHint: categoryHint,
      confidence: confidence,
    );
  }

  static const _onesWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  };

  static const _teenWords = {
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  };

  static const _tensWords = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  static double? _extractAmount(String text) {
    // Try digit-based amounts first — most reliable.
    final numericMatch = _numericAmountPattern.firstMatch(text);
    if (numericMatch != null) {
      final value = double.tryParse(numericMatch.group(1)!);
      if (value != null && value > 0) return value;
    }

    // Fall back to spoken number words: "forty five dollars"
    return _extractSpokenNumber(text);
  }

  /// Parses spoken number-word sequences into a dollar amount.
  ///
  /// This is genuinely ambiguous in natural English and required correcting
  /// a first-draft implementation that simply summed every number word —
  /// that approach got "forty five" right (45 = tens + ones, a standard
  /// compound number) but silently mis-parsed "twelve fifty" as 62 instead
  /// of the intended $12.50 (a "dollars and cents" spoken pattern, teens/ones
  /// word followed by a tens word). The classification below distinguishes
  /// these two genuinely different spoken patterns instead of assuming one
  /// interpretation always applies.
  static double? _extractSpokenNumber(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    final tokens = <(String kind, int value)>[];
    for (final word in words) {
      if (_tensWords.containsKey(word)) {
        tokens.add(('tens', _tensWords[word]!));
      } else if (_teenWords.containsKey(word)) {
        tokens.add(('teens', _teenWords[word]!));
      } else if (_onesWords.containsKey(word)) {
        tokens.add(('ones', _onesWords[word]!));
      } else if (word == 'hundred') {
        tokens.add(('hundred', 100));
      } else if (word == 'zero') {
        tokens.add(('ones', 0));
      }
    }

    if (tokens.isEmpty) return null;

    // "forty five" — tens followed by ones: standard compound number (45).
    if (tokens.length == 2 && tokens[0].$1 == 'tens' && tokens[1].$1 == 'ones') {
      return (tokens[0].$2 + tokens[1].$2).toDouble();
    }

    // "twelve fifty" / "nine fifty" — (ones or teens) followed by tens:
    // spoken as dollars-and-cents, e.g. $12.50, not 12+50=62.
    if (tokens.length == 2 &&
        (tokens[0].$1 == 'ones' || tokens[0].$1 == 'teens') &&
        tokens[1].$1 == 'tens') {
      return tokens[0].$2 + tokens[1].$2 / 100;
    }

    // "nine ninety nine" — (ones or teens), tens, ones: dollars-and-cents
    // with a two-digit cents value, e.g. $9.99.
    if (tokens.length == 3 &&
        (tokens[0].$1 == 'ones' || tokens[0].$1 == 'teens') &&
        tokens[1].$1 == 'tens' &&
        tokens[2].$1 == 'ones') {
      final cents = tokens[1].$2 + tokens[2].$2;
      return tokens[0].$2 + cents / 100;
    }

    // "one hundred" — value followed by the word "hundred".
    if (tokens.length == 2 && tokens[1].$1 == 'hundred') {
      return (tokens[0].$2 * 100).toDouble();
    }

    // Single spoken number word, e.g. just "twenty" or "five".
    if (tokens.length == 1) {
      return tokens[0].$2.toDouble();
    }

    // Anything else unrecognized falls back to summing the tokens found —
    // safer than returning nothing, though less precise for compound speech
    // patterns not explicitly handled above.
    final sum = tokens.fold<int>(0, (acc, t) => acc + t.$2);
    return sum > 0 ? sum.toDouble() : null;
  }

  /// Heuristic: prefer an explicit "at/from <Merchant>" phrase, since it's
  /// the clearest, least ambiguous signal in natural speech.
  static String? _extractMerchant(String text) {
    final match = _merchantAtPattern.firstMatch(text);
    if (match == null) return null;

    final raw = match.group(1)!.trim();
    if (raw.isEmpty || raw.length < 2) return null;

    // Reject if it's actually a category word misfiring as a merchant name
    // (e.g. "spent 12 at lunch" is unusual but guard against it anyway).
    if (_categoryKeywords.containsKey(raw.toLowerCase())) return null;

    return raw;
  }

  /// Maps spoken category words to the app's internal category ids so the
  /// review screen can pre-select a category chip, not just leave it blank.
  static String? _extractCategoryHint(String text) {
    final lower = text.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
