import 'package:intl/intl.dart';

const _currencySymbols = <String, String>{
  'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£',
  'JPY': '¥', 'AED': 'د.إ', 'AUD': 'A\$', 'CAD': 'C\$',
};

String currencySymbol(String code) => _currencySymbols[code] ?? '$code ';

String formatMoney(double amount, String currency, {bool compact = false, bool sign = false}) {
  final sym = currencySymbol(currency);
  final abs = amount.abs();
  String body;
  if (compact && abs >= 1000000) {
    body = '${(abs / 1000000).toStringAsFixed(abs >= 10000000 ? 1 : 2)}M';
  } else if (compact && abs >= 1000) {
    body = '${(abs / 1000).toStringAsFixed(abs >= 100000 ? 1 : 2)}K';
  } else {
    body = NumberFormat.currency(
      locale: 'en_IN', symbol: '', decimalDigits: 0,
    ).format(abs);
  }
  final s = amount < 0 ? '-' : (sign ? '+' : '');
  return '$s$sym$body';
}

String formatDate(DateTime d, {String style = 'short'}) {
  switch (style) {
    case 'rel':
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '${diff}d ago';
      if (diff < 30) return '${diff ~/ 7}w ago';
      return formatDate(d, style: 'short');
    case 'long':
      return DateFormat('d MMMM yyyy').format(d);
    case 'short':
    default:
      return DateFormat('d MMM').format(d);
  }
}

String formatWeekday(DateTime d) => DateFormat('EEE').format(d);

String formatDateISO(DateTime d) => d.toIso8601String();
String formatDateInput(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

int pct(double part, double whole) {
  if (whole <= 0) return 0;
  return (part / whole * 100).round().clamp(0, 100);
}

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

DateTime startOfMonth([DateTime? d]) {
  final now = d ?? DateTime.now();
  return DateTime(now.year, now.month, 1);
}

List<DateTime> lastNDays(int n) {
  final out = <DateTime>[];
  for (var i = n - 1; i >= 0; i--) {
    final d = DateTime.now().subtract(Duration(days: i));
    out.add(DateTime(d.year, d.month, d.day));
  }
  return out;
}

class FinancialHealthScore {
  final int score;
  final String grade;
  final String label;
  const FinancialHealthScore({required this.score, required this.grade, required this.label});
}

FinancialHealthScore financialHealthScore({
  required double income,
  required double expenses,
  required int budgetsOver,
  required int budgetsTotal,
  required int goalsOnTrack,
  required int goalsTotal,
}) {
  var score = 0;
  final rate = income > 0 ? (income - expenses) / income : 0.0;
  score += (rate * 100 * 0.45).clamp(0, 45).round();
  final adherence = budgetsTotal > 0 ? 1 - budgetsOver / budgetsTotal : 1.0;
  score += (adherence * 30).round();
  final goals = goalsTotal > 0 ? goalsOnTrack / goalsTotal : 1.0;
  score += (goals * 25).round();
  score = score.clamp(0, 100);
  String grade, label;
  if (score >= 85) { grade = 'A+'; label = 'Excellent'; }
  else if (score >= 70) { grade = 'A'; label = 'Great'; }
  else if (score >= 55) { grade = 'B'; label = 'Good'; }
  else if (score >= 40) { grade = 'C'; label = 'Fair'; }
  else { grade = 'D'; label = 'Needs work'; }
  return FinancialHealthScore(score: score, grade: grade, label: label);
}

double emi(double principal, double annualRate, int months) {
  final r = annualRate / 12 / 100;
  if (r == 0) return principal / months;
  return (principal * r * _pow(1 + r, months)) / (_pow(1 + r, months) - 1);
}

double sipFuture(double monthly, double annualRate, int months) {
  final r = annualRate / 12 / 100;
  if (r == 0) return monthly * months;
  return monthly * ((_pow(1 + r, months) - 1) / r) * (1 + r);
}

double _pow(double b, int e) {
  var r = 1.0;
  for (var i = 0; i < e; i++) {
    r *= b;
  }
  return r;
}

String uid([String prefix = '']) {
  return '$prefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${DateTime.now().microsecond.toRadixString(36)}';
}
