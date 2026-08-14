import 'package:equatable/equatable.dart';

class DashboardSummaryEntity extends Equatable {
  final double totalBalance;
  final double totalIncome;
  final double totalExpenses;
  final double savingsRate;
  final double budgetUsedPercent;
  final int activeSubscriptions;
  final double subscriptionsCost;
  final List<RecentTransactionEntity> recentTransactions;
  final List<SpendingCategoryEntity> topCategories;
  final List<double> weeklySpending; // 7 values, most recent last
  final FinancialHealthEntity financialHealth;

  const DashboardSummaryEntity({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.savingsRate,
    required this.budgetUsedPercent,
    required this.activeSubscriptions,
    required this.subscriptionsCost,
    required this.recentTransactions,
    required this.topCategories,
    required this.weeklySpending,
    required this.financialHealth,
  });

  @override
  List<Object?> get props => [
    totalBalance, totalIncome, totalExpenses, savingsRate,
    budgetUsedPercent, activeSubscriptions, subscriptionsCost,
    recentTransactions, topCategories, weeklySpending, financialHealth,
  ];
}

class RecentTransactionEntity extends Equatable {
  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final String? icon;
  final String? color;

  const RecentTransactionEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isExpense,
    required this.date,
    this.icon,
    this.color,
  });

  @override
  List<Object?> get props => [id, title, category, amount, isExpense, date];
}

class SpendingCategoryEntity extends Equatable {
  final String name;
  final double amount;
  final double percentage;
  final String color;
  final String icon;

  const SpendingCategoryEntity({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  @override
  List<Object?> get props => [name, amount, percentage, color, icon];
}

class FinancialHealthEntity extends Equatable {
  final int score; // 0-100
  final String grade; // A, B, C, D, F
  final String insight;
  final List<String> tips;

  const FinancialHealthEntity({
    required this.score,
    required this.grade,
    required this.insight,
    required this.tips,
  });

  @override
  List<Object?> get props => [score, grade, insight, tips];
}
