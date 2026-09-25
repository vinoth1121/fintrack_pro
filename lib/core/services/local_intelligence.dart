import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../providers/fintrack_provider.dart';
import '../utils/formatters.dart';

/// Local, offline intelligence engine for FinTrack Pro ("Lumina Local").
///
/// Replaces every hard dependency on the remote AI API key with deterministic,
/// on-device logic computed from the user's own local data:
///
///  * [parseVoiceText]     — natural-language transaction parsing (voice/typed)
///  * [parseReceiptText]   — receipt text → structured fields
///  * [buildInsights]      — insight cards, month-end forecast, anomalies
///  * [buildWeeklySummary] — weekly headline notification
///  * [assistantReply]     — Lumina chat answers grounded in local data
///
/// Nothing here touches the network. The app works fully offline and without
/// an AI API key; when a backend with a working provider IS reachable the
/// screens may still use it as an optional enhancement.
class LocalIntelligence {
  LocalIntelligence._();

  // ===========================================================================
  // Voice / typed transaction parsing
  // ===========================================================================

  static const _incomeSignals = <String>[
    'received', 'salary', 'credited', 'credit', 'income', 'earned', 'earn',
    'refund', 'bonus', 'cashback', 'dividend', 'interest', 'deposit',
    'sold', 'payment from', 'profit', 'stipend', 'withdrawal',
  ];

  static const _expenseCategoryKeywords = <String, List<String>>{
    'Food & Dining': [
      'food', 'dinner', 'lunch', 'breakfast', 'restaurant', 'swiggy', 'zomato',
      'cafe', 'coffee', 'pizza', 'burger', 'biryani', 'snack', 'meal', 'dhaba',
      'tea', 'juice', 'brunch', 'dessert',
    ],
    'Groceries': [
      'grocery', 'groceries', 'bigbasket', 'blinkit', 'zepto', 'supermarket',
      'vegetables', 'fruits', 'milk', 'kirana', 'dmart', 'ration',
    ],
    'Transport': [
      'uber', 'ola', 'rapido', 'cab', 'taxi', 'fuel', 'petrol', 'diesel',
      'metro', 'bus', 'train', 'irctc', 'parking', 'toll', 'auto', 'ride',
    ],
    'Shopping': [
      'shopping', 'amazon', 'flipkart', 'myntra', 'ajio', 'clothes', 'shirt',
      'shoes', 'electronics', 'gadget', 'dress', 'headphones', 'jacket',
    ],
    'Bills & Utilities': [
      'bill', 'bills', 'electricity', 'water bill', 'gas bill', 'internet',
      'wifi', 'broadband', 'recharge', 'airtel', 'jio', 'postpaid', 'dth',
      'utility', 'utilities', 'phone bill',
    ],
    'Rent & Housing': [
      'rent', 'housing', 'maintenance', 'society', 'landlord', 'apartment',
    ],
    'Health': [
      'doctor', 'medicine', 'medicines', 'pharmacy', 'hospital', 'clinic',
      'health', 'gym', 'apollo', 'tablet', 'medical', 'checkup', 'dentist',
    ],
    'Entertainment': [
      'movie', 'movies', 'netflix', 'spotify', 'bookmyshow', 'game', 'games',
      'concert', 'entertainment', 'hotstar', 'prime', 'show',
    ],
    'Education': [
      'course', 'courses', 'book', 'books', 'udemy', 'coursera', 'school',
      'college', 'tuition', 'exam', 'fees', 'coaching', 'class',
    ],
    'Travel': [
      'flight', 'flights', 'trip', 'travel', 'airbnb', 'oyo', 'vacation',
      'tour', 'visa', 'hotel booking',
    ],
    'Investments': [
      'sip', 'mutual fund', 'stock', 'stocks', 'zerodha', 'investment',
      'invest', 'groww', 'fd', 'fixed deposit', 'shares', 'etf',
    ],
    'Gifts': ['gift', 'gifts', 'donation', 'donate', 'birthday'],
  };

  static const _incomeCategoryKeywords = <String, List<String>>{
    'Salary': ['salary', 'payroll', 'paycheck', 'stipend', 'pay day'],
    'Freelance': ['freelance', 'upwork', 'fiverr', 'client', 'consulting', 'gig'],
    'Investments': ['dividend', 'interest', 'returns', 'profit', 'capital gain'],
    'Gifts': ['gift', 'bonus', 'cashback', 'refund', 'reward'],
  };

  /// Words that terminate a merchant capture.
  static const _merchantStops = <String>[
    'for', 'on', 'at', 'by', 'using', 'via', 'cash', 'card', 'upi', 'today',
    'yesterday', 'tomorrow', 'with', 'through', 'from', 'to', 'in', 'and',
    'rs', 'inr', 'rupees',
  ];

  /// Parse natural-language text (typed or spoken) into a transaction draft.
  /// Always succeeds; fields that can't be inferred are left for the user.
  static ParsedTransaction parseVoiceText(String transcript, {DateTime? today}) {
    final raw = transcript.trim();
    final lower = raw.toLowerCase();
    final now = today ?? DateTime.now();
    final todayStr = formatDateInput(now);

    if (raw.isEmpty) {
      return ParsedTransaction(
        type: 'expense', amount: null, merchant: '', category: 'Other',
        date: todayStr, note: '',
      );
    }

    // ── Type ────────────────────────────────────────────────────────────────
    final isIncome = _incomeSignals.any((k) => lower.contains(k));

    // ── Amount ──────────────────────────────────────────────────────────────
    final amount = _extractAmount(lower);

    // ── Date ────────────────────────────────────────────────────────────────
    final date = _extractDate(lower, now);

    // ── Category (+ matched keyword for merchant fallback) ─────────────────
    String category = isIncome ? 'Other' : 'Other';
    String? matchedKeyword;
    final map = isIncome ? _incomeCategoryKeywords : _expenseCategoryKeywords;
    outer:
    for (final entry in map.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          category = entry.key;
          matchedKeyword = kw;
          break outer;
        }
      }
    }

    // ── Merchant ────────────────────────────────────────────────────────────
    var merchant = _extractMerchant(raw);
    if (merchant.isEmpty && matchedKeyword != null) {
      merchant = _titleCase(matchedKeyword);
    }

    return ParsedTransaction(
      type: isIncome ? 'income' : 'expense',
      amount: amount,
      merchant: merchant,
      category: category,
      date: date,
      note: raw.length > 100 ? raw.substring(0, 100) : raw,
    );
  }

  static double? _extractAmount(String lower) {
    // Strip date-like tokens so "2026-08-25" never becomes the amount.
    var cleaned = lower
        .replaceAll(RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b'), ' ');

    // Prefer currency-adjacent numbers ("₹540", "rs 1.2k").
    final currencyFirst = RegExp(
      r'(?:₹|rs\.?|inr|\$)\s*([0-9][0-9,]*(?:\.\d+)?)\s*(k\b)?',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (currencyFirst != null) {
      var v = double.tryParse(currencyFirst.group(1)!.replaceAll(',', ''));
      if (v != null && currencyFirst.group(2) != null) v *= 1000;
      return v;
    }

    // Otherwise first number, supporting the "k" suffix ("1.5k" → 1500).
    final m = RegExp(
      r'([0-9][0-9,]*(?:\.\d+)?)\s*(k\b)?',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (m == null) return null;
    var value = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (value == null) return null;
    if (m.group(2) != null) value *= 1000;
    return value;
  }

  static String _extractDate(String lower, DateTime now) {
    String fmt(DateTime d) => formatDateInput(d);

    final iso = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(lower);
    if (iso != null) return iso.group(1)!;

    final dmy = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b').firstMatch(lower);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final m = int.parse(dmy.group(2)!);
      var y = int.parse(dmy.group(3)!);
      if (y < 100) y += 2000;
      return fmt(DateTime(y, m, d));
    }

    if (lower.contains('day before yesterday')) return fmt(now.subtract(const Duration(days: 2)));
    if (lower.contains('yesterday')) return fmt(now.subtract(const Duration(days: 1)));
    if (lower.contains('tomorrow')) return fmt(now.add(const Duration(days: 1)));

    // "on 15th" / "on the 3rd"
    final dayOfMonth = RegExp(r'\bon(?:\s+the)?\s+(\d{1,2})(?:st|nd|rd|th)?\b')
        .firstMatch(lower);
    if (dayOfMonth != null) {
      final d = int.parse(dayOfMonth.group(1)!);
      if (d >= 1 && d <= 31) {
        final maxDay = _daysInMonth(now.year, now.month);
        return fmt(DateTime(now.year, now.month, d.clamp(1, maxDay)));
      }
    }

    return fmt(now);
  }

  static String _extractMerchant(String raw) {
    final m = RegExp(
      r"\b(?:at|from|to)\s+([A-Za-z0-9&.'\-]+(?:\s+[A-Za-z0-9&.'\-]+){0,3})",
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return '';
    var capture = m.group(1)!.trim();
    // Cut at the first stop-word boundary: "dinner at Swiggy yesterday" → "Swiggy"
    final tokens = capture.split(RegExp(r'\s+'));
    final kept = <String>[];
    for (final tok in tokens) {
      if (_merchantStops.contains(tok.toLowerCase())) break;
      kept.add(tok);
    }
    capture = kept.join(' ').trim();
    // Reject pure-number captures ("at 540").
    if (capture.isEmpty || double.tryParse(capture.replaceAll(',', '')) != null) {
      return '';
    }
    return _titleCase(capture);
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  // ===========================================================================
  // Receipt text parsing (offline)
  // ===========================================================================

  /// Parse receipt text into structured fields. Works on pasted/OCR text.
  /// Every field has a safe default — never returns null, never throws.
  static ReceiptData parseReceiptText(String rawText, {String defaultCurrency = 'INR'}) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final joined = lines.join('\n');
    final lower = joined.toLowerCase();

    // Merchant: first line with at least one letter.
    var merchant = '';
    for (final line in lines) {
      if (RegExp(r'[A-Za-z]').hasMatch(line) && line.length <= 60) {
        merchant = line;
        break;
      }
    }

    // Total: explicit "total" lines win; else the largest amount on the slip.
    double? total = _amountAfterLabels(lower, const [
      'grand total', 'total amount', 'amount due', 'balance due', 'net total', 'total',
    ]);
    final allAmounts = RegExp(r'([0-9][0-9,]*\.\d{1,2})')
        .allMatches(joined)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0)
        .where((v) => v > 0)
        .toList();
    total ??= allAmounts.isEmpty ? null : allAmounts.reduce((a, b) => a > b ? a : b);

    // Subtotal / tax
    final subtotal = _amountAfterLabels(lower, const ['subtotal', 'sub total']);
    double? tax = _amountAfterLabels(lower, const ['total tax', 'tax', 'gst', 'vat']);
    if (tax == null) {
      final cgst = _amountAfterLabels(lower, const ['cgst']) ?? 0;
      final sgst = _amountAfterLabels(lower, const ['sgst']) ?? 0;
      if (cgst + sgst > 0) tax = cgst + sgst;
    }

    // Date
    String? date;
    final now = DateTime.now();
    final iso = RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2})').firstMatch(joined);
    if (iso != null) {
      date = iso.group(1)!.replaceAll('/', '-');
    } else {
      final dmy = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b').firstMatch(joined);
      if (dmy != null) {
        final d = int.parse(dmy.group(1)!);
        final mth = int.parse(dmy.group(2)!);
        var y = int.parse(dmy.group(3)!);
        if (y < 100) y += 2000;
        date = formatDateInput(DateTime(y, mth, d));
      }
    }

    // Items: "Name 2 x 30.00" or "Name .... 60.00"
    final items = <ReceiptItem>[];
    for (final line in lines) {
      final qtyPrice = RegExp(r'^(.*?)[\s]+(\d+)\s*[x×@]\s*([0-9]+(?:\.[0-9]+)?)$')
          .firstMatch(line);
      if (qtyPrice != null) {
        items.add(ReceiptItem(
          qtyPrice.group(1)!.trim(),
          int.tryParse(qtyPrice.group(2)!),
          double.tryParse(qtyPrice.group(3)!),
        ));
        continue;
      }
      final tailPrice = RegExp(r'^(.*?[A-Za-z])[\s.]+([0-9]+(?:\.[0-9]{1,2}))$')
          .firstMatch(line);
      if (tailPrice != null &&
          !_looksLikeTotalLine(tailPrice.group(1)!.toLowerCase())) {
        items.add(ReceiptItem(
          tailPrice.group(1)!.replaceAll(RegExp(r'[.\s]+$'), '').trim(),
          1,
          double.tryParse(tailPrice.group(2)!),
        ));
      }
    }

    // Currency: respect symbols on the slip, else app default.
    var currency = defaultCurrency;
    if (lower.contains('₹') || RegExp(r'\brs\.?\b').hasMatch(lower)) {
      currency = 'INR';
    } else if (joined.contains(r'$')) {
      currency = 'USD';
    } else if (joined.contains('€')) {
      currency = 'EUR';
    } else if (joined.contains('£')) {
      currency = 'GBP';
    }

    // Category from keywords over merchant + items.
    var category = 'Other';
    final haystack = lower;
    outer:
    for (final entry in _expenseCategoryKeywords.entries) {
      for (final kw in entry.value) {
        if (haystack.contains(kw)) {
          category = entry.key;
          break outer;
        }
      }
    }

    final totalVal = total ?? 0;
    final subtotalVal = subtotal ?? totalVal;
    final taxVal = tax ?? (totalVal - subtotalVal).clamp(0, double.infinity);

    return ReceiptData(
      merchant: merchant.isEmpty ? 'Scanned Receipt' : merchant,
      total: totalVal,
      subtotal: subtotalVal,
      tax: taxVal.toDouble(),
      date: date ?? formatDateInput(now),
      currency: currency,
      category: category,
      items: items,
      rawText: rawText,
    );
  }

  static bool _looksLikeTotalLine(String label) => const [
        'total', 'subtotal', 'sub total', 'tax', 'gst', 'vat', 'cgst', 'sgst',
        'change', 'cash', 'amount due', 'balance', 'round', 'discount',
      ].any((k) => label.contains(k));

  static double? _amountAfterLabels(String lower, List<String> labels) {
    for (final label in labels) {
      final re = RegExp(
        '${RegExp.escape(label)}'
        r'\s*[:\-]?\s*(?:rs\.?|inr|₹|\$)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)',
        caseSensitive: false,
      );
      final m = re.firstMatch(lower);
      if (m != null) {
        return double.tryParse(m.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  // ===========================================================================
  // Insights (cards + forecast + anomalies) — computed fully on-device
  // ===========================================================================

  static InsightsPayload buildInsights(FinTrackState s) {
    final now = DateTime.now();
    final monthTx = s.transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
    final monthExpenses = monthTx
        .where((t) => t.type == TxType.expense)
        .fold(0.0, (a, t) => a + t.amount);
    final monthIncome = monthTx
        .where((t) => t.type == TxType.income)
        .fold(0.0, (a, t) => a + t.amount);
    final cur = s.profile.baseCurrency;
    String money(double v) => formatMoney(v, cur);

    final nameOf = <String, String>{for (final c in s.categories) c.id: c.name};

    // Category totals (this month, expenses only)
    final byCat = <String, double>{};
    for (final t in monthTx) {
      if (t.type != TxType.expense) continue;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Budget usage (recomputed from local month data)
    final budgetUsage = s.budgets.map((b) {
      final spent = monthTx
          .where((t) => t.type == TxType.expense && t.categoryId == b.categoryId)
          .fold(0.0, (a, t) => a + t.amount);
      final pctVal = b.limit > 0 ? spent / b.limit : 0.0;
      return (budget: b, spent: spent, pct: pctVal);
    }).toList();

    // ── Cards ───────────────────────────────────────────────────────────────
    final cards = <InsightCard>[];
    var n = 0;
    String nextId() => '${++n}';

    if (sortedCats.isNotEmpty && monthExpenses > 0) {
      final top = sortedCats.first;
      final name = nameOf[top.key] ?? 'Other';
      final share = (top.value / monthExpenses * 100).round();
      cards.add(InsightCard(
        id: nextId(), kind: 'tip',
        title: 'Top category: $name',
        body: 'You spent ${money(top.value)} on $name this month — $share% of your total spend.',
        icon: 'wallet', accent: 'iris', metric: '$share%',
      ));
    }

    // Forecast card
    final day = now.day;
    final daysInMonth = _daysInMonth(now.year, now.month);
    final projected = day > 0 ? monthExpenses / day * daysInMonth : monthExpenses;
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prevExp = s.transactions
        .where((t) =>
            t.type == TxType.expense &&
            t.date.year == prevMonth.year &&
            t.date.month == prevMonth.month)
        .fold(0.0, (a, t) => a + t.amount);
    final delta = prevExp > 0 ? (monthExpenses - prevExp) / prevExp * 100 : 0.0;
    final trend = delta > 8 ? 'up' : (delta < -8 ? 'down' : 'flat');
    cards.add(InsightCard(
      id: nextId(), kind: 'forecast',
      title: 'Month-end forecast',
      body: monthTx.isEmpty
          ? 'Add a few transactions and I can project your month-end spend.'
          : 'At the current pace you will spend about ${money(projected)} by ${_daysInMonth(now.year, now.month)} ${monthName(now.month)}.',
      icon: trend == 'down' ? 'trending_down' : 'trending_up',
      accent: trend == 'up' ? 'amber' : 'green',
      metric: money(projected),
    ));

    // Budget adherence card
    if (budgetUsage.isNotEmpty) {
      final over = budgetUsage.where((u) => u.pct > 1).toList();
      if (over.isNotEmpty) {
        final worst = over.reduce((a, b) => a.pct > b.pct ? a : b);
        final name = nameOf[worst.budget.categoryId] ?? 'Budget';
        cards.add(InsightCard(
          id: nextId(), kind: 'warning',
          title: '$name budget exceeded',
          body: 'You have spent ${money(worst.spent)} of ${money(worst.budget.limit)} (${(worst.pct * 100).round()}%). Consider pausing non-essential $name spending.',
          icon: 'alert', accent: 'red',
          metric: '${(worst.pct * 100).round()}%',
        ));
      } else {
        final closest = budgetUsage.reduce((a, b) => a.pct > b.pct ? a : b);
        final name = nameOf[closest.budget.categoryId] ?? 'Budget';
        cards.add(InsightCard(
          id: nextId(), kind: 'tip',
          title: 'Budgets under control',
          body: 'Closest is $name at ${(closest.pct * 100).round()}% used (${money(closest.spent)} of ${money(closest.budget.limit)}).',
          icon: 'shield', accent: 'green',
          metric: '${(closest.pct * 100).round()}%',
        ));
      }
    }

    // Savings rate card
    final rate = monthIncome > 0 ? (monthIncome - monthExpenses) / monthIncome : 0.0;
    cards.add(InsightCard(
      id: nextId(), kind: 'tip',
      title: 'Savings rate: ${(rate * 100).round()}%',
      body: rate >= 0.2
          ? 'Strong month — you kept ${money(monthIncome - monthExpenses)} of ${money(monthIncome)} earned. Consider moving the surplus to a goal.'
          : monthIncome == 0
              ? 'Log your income to start tracking how much you keep each month.'
              : 'You kept ${money(monthIncome - monthExpenses)} this month. Aim for 20% — trimming your top category would get you closer.',
      icon: rate >= 0.2 ? 'trophy' : 'lightbulb',
      accent: rate >= 0.2 ? 'green' : 'amber',
      metric: '${(rate * 100).round()}%',
    ));

    // Goal progress card
    if (s.goals.isNotEmpty) {
      final best = s.goals.reduce((a, b) =>
          (a.target > 0 ? a.saved / a.target : 0) > (b.target > 0 ? b.saved / b.target : 0) ? a : b);
      final pctGoal = best.target > 0 ? (best.saved / best.target * 100).round() : 0;
      cards.add(InsightCard(
        id: nextId(), kind: 'tip',
        title: 'Closest goal: ${best.name}',
        body: '${money(best.saved)} saved of ${money(best.target)} — $pctGoal% there. Every small contribution compounds.',
        icon: 'target', accent: 'cyan', metric: '$pctGoal%',
      ));
    }

    // Subscription load card
    var subMonthly = 0.0;
    var activeCount = 0;
    for (final sub in s.subscriptions) {
      if (!sub.active) continue;
      activeCount++;
      subMonthly += sub.cycle == 'yearly'
          ? sub.amount / 12
          : sub.cycle == 'weekly'
              ? sub.amount * 4.33
              : sub.amount;
    }
    if (activeCount > 0) {
      cards.add(InsightCard(
        id: nextId(), kind: 'tip',
        title: 'Subscriptions: ${money(subMonthly)}/month',
        body: '$activeCount active subscriptions. Review ones you have not used recently — cancelling one frees cash for your goals.',
        icon: 'calendar', accent: 'amber', metric: money(subMonthly),
      ));
    }

    // ── Weekly summary (last 7 days vs previous 7) ──────────────────────────
    final weekData = _weeklyData(s.transactions, nameOf);

    // ── Anomalies: expenses far above the month's average ───────────────────
    final expenses = monthTx.where((t) => t.type == TxType.expense).toList();
    final anomalies = <Anomaly>[];
    if (expenses.length >= 4) {
      final avg = monthExpenses / expenses.length;
      for (final t in expenses) {
        if (avg > 0 && t.amount > avg * 2.5) {
          anomalies.add(Anomaly(
            formatDateInput(t.date),
            t.merchant ?? (nameOf[t.categoryId] ?? 'Expense'),
            t.amount,
            'Unusually high ${nameOf[t.categoryId] ?? 'expense'} — ${(t.amount / avg).toStringAsFixed(1)}× your average',
          ));
        }
      }
      anomalies.sort((a, b) => b.amount.compareTo(a.amount));
    }

    return InsightsPayload(
      cards: cards.take(6).toList(),
      forecast: Forecast(
        projected,
        day >= 20 ? 'high' : (day >= 8 ? 'medium' : 'low'),
        daysInMonth - day,
        trend,
      ),
      weeklySummary: weekData,
      anomalies: anomalies.take(5).toList(),
    );
  }

  static WeeklySummaryData _weeklyData(
      List<Transaction> txs, Map<String, String> nameOf) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    final prevStart = weekStart.subtract(const Duration(days: 7));

    double spent = 0, income = 0, prevSpent = 0;
    final byCat = <String, double>{};
    for (final t in txs) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (!d.isBefore(weekStart)) {
        if (t.type == TxType.expense) {
          spent += t.amount;
          byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
        } else {
          income += t.amount;
        }
      } else if (!d.isBefore(prevStart)) {
        if (t.type == TxType.expense) prevSpent += t.amount;
      }
    }

    String topName = '—';
    var topAmount = 0.0;
    if (byCat.isNotEmpty) {
      final top = byCat.entries.reduce((a, b) => a.value > b.value ? a : b);
      topName = nameOf[top.key] ?? 'Other';
      topAmount = top.value;
    }
    final vsPrev = prevSpent > 0 ? ((spent - prevSpent) / prevSpent * 100).round() : 0;

    return WeeklySummaryData(spent, income, topName, topAmount, vsPrev);
  }

  static String monthName(int month) => const [
        'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December',
      ][month - 1];

  /// Days in a month without depending on Flutter's DateUtils
  /// (this service stays pure Dart so it is trivially unit-testable).
  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  // ===========================================================================
  // Weekly summary notification text
  // ===========================================================================

  static WeeklySummary buildWeeklySummary(FinTrackState s) {
    final cur = s.profile.baseCurrency;
    String money(double v) => formatMoney(v, cur);
    final nameOf = <String, String>{for (final c in s.categories) c.id: c.name};
    final w = _weeklyData(s.transactions, nameOf);

    if (w.weekSpent == 0 && w.weekIncome == 0) {
      return const WeeklySummary(
        title: 'Your week at a glance',
        body: 'No transactions in the last 7 days yet. Add a few and your weekly summary comes alive.',
        highlights: ['Nothing tracked this week yet', 'Tip: voice entry takes 5 seconds'],
      );
    }

    final dir = w.vsLastWeekPct > 0
        ? 'up ${w.vsLastWeekPct}%'
        : w.vsLastWeekPct < 0
            ? 'down ${w.vsLastWeekPct.abs()}%'
            : 'about the same as';

    return WeeklySummary(
      title: 'Your week at a glance',
      body:
          'You spent ${money(w.weekSpent)}${w.weekIncome > 0 ? ' and earned ${money(w.weekIncome)}' : ''} in the last 7 days — $dir compared to the week before.${w.topCategory != '—' ? ' Biggest category: ${w.topCategory}.' : ''}',
      highlights: [
        'Spending: ${money(w.weekSpent)}',
        if (w.weekIncome > 0) 'Income: ${money(w.weekIncome)}',
        if (w.topCategory != '—')
          'Top category: ${w.topCategory} (${money(w.topCategoryAmount)})',
        if (w.vsLastWeekPct != 0) 'vs last week: $dir',
      ],
    );
  }

  // ===========================================================================
  // Lumina assistant — answers from the user's own local data only
  // ===========================================================================

  static String assistantReply(String message, FinTrackState s, DerivedData d) {
    final q = message.toLowerCase().trim();
    final cur = s.profile.baseCurrency;
    String money(double v) => formatMoney(v, cur);

    if (q.isEmpty) {
      return 'Ask me about your spending, budgets, goals or subscriptions — I only use the data inside your FinTrack Pro app.';
    }

    // ── Greeting ────────────────────────────────────────────────────────────
    if (RegExp(r'^(hi|hello|hey|yo|good (morning|evening|afternoon))\b')
        .hasMatch(q)) {
      return 'Hello ${s.profile.name.split(' ').first}! Here is your snapshot:\n\n'
          '• This month: ${money(d.monthIncome)} in, ${money(d.monthExpenses)} out\n'
          '• Savings rate: ${(d.savingsRate * 100).round()}%\n'
          '• Net balance: ${money(d.netBalance)}\n\n'
          'Ask me things like "where did my money go?" or "which budget am I close to exceeding?".';
    }

    // ── Budgets ─────────────────────────────────────────────────────────────
    if (_any(q, const ['budget', 'over budget', 'exceed'])) {
      if (d.budgetUsage.isEmpty) {
        return 'You have no budgets yet. Create one from the Budget tab — then I can warn you before you overspend.';
      }
      final lines = d.budgetUsage.map((b) =>
          '• ${b.categoryName}: ${money(b.spent)} of ${money(b.limit)} (${b.pct}%${b.over ? ' — OVER' : ''})');
      final over = d.budgetUsage.where((b) => b.over).toList();
      final closest = d.budgetUsage.reduce((a, b) => a.pct > b.pct ? a : b);
      final advice = over.isNotEmpty
          ? '${over.map((b) => b.categoryName).join(', ')} ${over.length == 1 ? 'is' : 'are'} already over the limit.'
          : 'Closest to its limit: ${closest.categoryName} at ${closest.pct}%.';
      return 'Here is your budget status:\n\n${lines.join('\n')}\n\n$advice';
    }

    // ── Goals / savings goals ───────────────────────────────────────────────
    if (_any(q, const ['goal', 'forecast when', 'hit my savings'])) {
      if (s.goals.isEmpty) {
        return 'No savings goals yet. Create one from Savings Goals and I can track progress and forecast completion dates.';
      }
      final buf = StringBuffer('Your savings goals:\n\n');
      for (final g in s.goals) {
        final pctGoal = g.target > 0 ? ((g.saved / g.target) * 100).round() : 0;
        var line = '• ${g.name}: ${money(g.saved)} / ${money(g.target)} ($pctGoal%)';
        if (g.deadline != null) {
          final left = g.deadline!.difference(DateTime.now()).inDays;
          if (left > 0 && g.saved < g.target) {
            final perDay = (g.target - g.saved) / left;
            line += ' — ${money(perDay)}/day for $left days to finish on time';
          } else if (g.saved >= g.target) {
            line += ' — completed!';
          } else {
            line += ' — deadline passed';
          }
        }
        buf.writeln(line);
      }
      return buf.toString().trim();
    }

    // ── Savings rate / saving tips ──────────────────────────────────────────
    if (_any(q, const ['savings rate', 'save more', 'improve my savings', 'how can i save', 'saving'])) {
      final ratePct = (d.savingsRate * 100).round();
      final topCat = d.categoryBreakdown.isNotEmpty ? d.categoryBreakdown.first : null;
      final buffer = StringBuffer()
        ..writeln('Your savings rate this month is $ratePct% (${money(d.monthIncome - d.monthExpenses)} kept of ${money(d.monthIncome)}).');
      if (ratePct >= 20) {
        buffer.writeln('\nThat is a healthy rate — anything above 20% is strong.');
      } else {
        buffer.writeln('\nTo reach a healthy 20%:');
        if (topCat != null) {
          buffer.writeln('• Trim ${topCat.name} (your biggest category at ${money(topCat.amount)}, ${topCat.pct}% of spend)');
        }
        buffer.writeln('• Set a budget per category so overspend shows up immediately');
        buffer.writeln('• Move ${money(d.monthIncome * 0.2)} to a savings goal the day income lands');
      }
      return buffer.toString().trim();
    }

    // ── Subscriptions ───────────────────────────────────────────────────────
    if (_any(q, const ['subscription', 'subscriptions', 'renewal', 'recurring'])) {
      final active = s.subscriptions.where((x) => x.active).toList();
      if (active.isEmpty) return 'You have no active subscriptions tracked.';
      var monthly = 0.0;
      for (final sub in active) {
        monthly += sub.cycle == 'yearly'
            ? sub.amount / 12
            : sub.cycle == 'weekly'
                ? sub.amount * 4.33
                : sub.amount;
      }
      final next = active.reduce((a, b) => a.nextBilling.isBefore(b.nextBilling) ? a : b);
      final days = next.nextBilling.difference(DateTime.now()).inDays;
      return 'You have ${active.length} active subscriptions costing about ${money(monthly)}/month.\n\n'
          'Next renewal: ${next.name} — ${money(next.amount)} ${days <= 0 ? 'today' : 'in $days days'}.\n\n'
          'Worth reviewing: cancelling one you barely use adds straight to savings.';
    }

    // ── Balance / net worth ─────────────────────────────────────────────────
    if (_any(q, const ['balance', 'net worth', 'total money', 'how much do i have'])) {
      final lines = s.accounts.map((a) => '• ${a.name}: ${money(a.balance)}');
      return 'Your accounts add up to ${money(d.netBalance)}:\n\n${lines.join('\n')}';
    }

    // ── Income ──────────────────────────────────────────────────────────────
    if (_any(q, const ['income', 'earn', 'earned', 'salary'])) {
      return 'Income this month: ${money(d.monthIncome)}'
          '${d.incomeDelta != 0 ? ' (${d.incomeDelta >= 0 ? '+' : ''}${d.incomeDelta.round()}% vs last month)' : ''}.\n'
          'All-time tracked income: ${money(d.totalIncome)}.';
    }

    // ── Forecast ────────────────────────────────────────────────────────────
    if (_any(q, const ['forecast', 'predict', 'projection', 'end of the month', 'end of month'])) {
      final now = DateTime.now();
      final days = _daysInMonth(now.year, now.month);
      final projected = now.day > 0 ? d.monthExpenses / now.day * days : d.monthExpenses;
      return 'Based on the ${now.day} days elapsed, you are on pace to spend about '
          '${money(projected)} by ${monthName(now.month)} $days '
          '(vs ${money(d.monthIncome)} income this month). '
          '${projected > d.monthIncome && d.monthIncome > 0 ? 'That exceeds your income — worth trimming discretionary spend now.' : 'That leaves room to save.'}';
    }

    // ── Spending (default analytical answer) ────────────────────────────────
    if (_any(q, const ['spend', 'spent', 'expense', 'money go', 'money went', 'biggest', 'largest', 'top category', 'where did'])) {
      final buf = StringBuffer()
        ..writeln('You spent ${money(d.monthExpenses)} this month'
            '${d.expenseDelta != 0 ? ' (${d.expenseDelta >= 0 ? '+' : ''}${d.expenseDelta.round()}% vs last month)' : ''}.');
      if (d.categoryBreakdown.isNotEmpty) {
        buf.writeln('\nTop categories:');
        for (final c in d.categoryBreakdown.take(3)) {
          buf.writeln('• ${c.name}: ${money(c.amount)} (${c.pct}%)');
        }
      }
      return buf.toString().trim();
    }

    // ── Help ────────────────────────────────────────────────────────────────
    if (_any(q, const ['help', 'what can you', 'how do you work', 'who are you'])) {
      return 'I am Lumina — your offline financial assistant. I answer using only your FinTrack Pro data (no internet, no external info). Try:\n\n'
          '• "Analyze my spending this month"\n'
          '• "Which budget am I closest to exceeding?"\n'
          '• "Forecast when I\'ll hit my savings goals"\n'
          '• "What is my net worth?"\n'
          '• "How can I improve my savings rate?"';
    }

    // ── Fallback ────────────────────────────────────────────────────────────
    return 'Here is your current picture: ${money(d.monthIncome)} in, ${money(d.monthExpenses)} out this month, '
        'savings rate ${(d.savingsRate * 100).round()}%, net balance ${money(d.netBalance)}.\n\n'
        'I focus on your FinTrack Pro data only — ask me about spending, budgets, goals, subscriptions, or forecasts.';
  }

  static bool _any(String q, List<String> needles) =>
      needles.any((n) => q.contains(n));
}
