/// Pure financial calculation engine — no Flutter/UI dependencies.
/// Kept separate from presentation so the math is independently testable
/// and reusable if a web/desktop client is added later.
library;

/// Result of an EMI (Equated Monthly Installment) calculation.
class EmiResult {
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final List<EmiScheduleEntry> schedule;

  const EmiResult({
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });
}

class EmiScheduleEntry {
  final int month;
  final double principal;
  final double interest;
  final double remainingBalance;

  const EmiScheduleEntry({
    required this.month,
    required this.principal,
    required this.interest,
    required this.remainingBalance,
  });
}

/// Result of a GST (Goods and Services Tax) calculation.
class GstResult {
  final double baseAmount;
  final double gstAmount;
  final double totalAmount;
  final double rate;

  const GstResult({
    required this.baseAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.rate,
  });
}

/// Result of a savings/compound-interest projection.
class SavingsResult {
  final double totalContributions;
  final double totalInterestEarned;
  final double finalAmount;
  final List<SavingsYearEntry> yearlyBreakdown;

  const SavingsResult({
    required this.totalContributions,
    required this.totalInterestEarned,
    required this.finalAmount,
    required this.yearlyBreakdown,
  });
}

class SavingsYearEntry {
  final int year;
  final double contributions;
  final double interestEarned;
  final double balance;

  const SavingsYearEntry({
    required this.year,
    required this.contributions,
    required this.interestEarned,
    required this.balance,
  });
}

abstract final class FinancialCalculators {
  /// Standard amortizing loan EMI calculation.
  /// [principal] loan amount, [annualRatePercent] e.g. 8.5 for 8.5%,
  /// [tenureMonths] loan duration in months.
  static EmiResult calculateEmi({
    required double principal,
    required double annualRatePercent,
    required int tenureMonths,
  }) {
    if (tenureMonths <= 0 || principal <= 0) {
      return const EmiResult(monthlyPayment: 0, totalPayment: 0, totalInterest: 0, schedule: []);
    }

    final monthlyRate = annualRatePercent / 12 / 100;

    final double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      final factor = _pow(1 + monthlyRate, tenureMonths);
      emi = (principal * monthlyRate * factor) / (factor - 1);
    }

    final schedule = <EmiScheduleEntry>[];
    var balance = principal;
    for (int month = 1; month <= tenureMonths; month++) {
      final interestPortion = balance * monthlyRate;
      final principalPortion = emi - interestPortion;
      balance = (balance - principalPortion).clamp(0, double.infinity);
      schedule.add(EmiScheduleEntry(
        month: month,
        principal: principalPortion,
        interest: interestPortion,
        remainingBalance: balance,
      ),);
    }

    final totalPayment = emi * tenureMonths;
    return EmiResult(
      monthlyPayment: emi,
      totalPayment: totalPayment,
      totalInterest: totalPayment - principal,
      schedule: schedule,
    );
  }

  /// GST calculation. If [isInclusive] is true, [amount] already contains GST
  /// and we back-calculate the base; otherwise GST is added on top.
  static GstResult calculateGst({
    required double amount,
    required double ratePercent,
    required bool isInclusive,
  }) {
    if (isInclusive) {
      final baseAmount = amount / (1 + ratePercent / 100);
      final gstAmount = amount - baseAmount;
      return GstResult(baseAmount: baseAmount, gstAmount: gstAmount, totalAmount: amount, rate: ratePercent);
    } else {
      final gstAmount = amount * ratePercent / 100;
      return GstResult(baseAmount: amount, gstAmount: gstAmount, totalAmount: amount + gstAmount, rate: ratePercent);
    }
  }

  /// Compound savings projection with regular monthly contributions.
  /// [initialAmount] starting balance, [monthlyContribution] added each month,
  /// [annualRatePercent] expected annual return, [years] projection horizon.
  static SavingsResult calculateSavings({
    required double initialAmount,
    required double monthlyContribution,
    required double annualRatePercent,
    required int years,
  }) {
    if (years <= 0) {
      return const SavingsResult(totalContributions: 0, totalInterestEarned: 0, finalAmount: 0, yearlyBreakdown: []);
    }

    final monthlyRate = annualRatePercent / 12 / 100;
    var balance = initialAmount;
    var totalContributions = initialAmount;
    final yearly = <SavingsYearEntry>[];

    for (int year = 1; year <= years; year++) {
      var yearContributions = 0.0;
      var yearInterest = 0.0;

      for (int month = 1; month <= 12; month++) {
        final interest = balance * monthlyRate;
        balance += interest + monthlyContribution;
        yearInterest += interest;
        yearContributions += monthlyContribution;
      }

      totalContributions += yearContributions;
      yearly.add(SavingsYearEntry(
        year: year,
        contributions: yearContributions,
        interestEarned: yearInterest,
        balance: balance,
      ),);
    }

    return SavingsResult(
      totalContributions: totalContributions,
      totalInterestEarned: balance - totalContributions,
      finalAmount: balance,
      yearlyBreakdown: yearly,
    );
  }

  static double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
