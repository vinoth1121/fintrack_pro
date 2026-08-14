import 'package:equatable/equatable.dart';

class CategoryBreakdownEntity extends Equatable {
  final String name;
  final String icon;
  final String color;
  final double amount;
  final int transactionCount;
  final double percentage;

  const CategoryBreakdownEntity({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });

  @override
  List<Object?> get props => [name, icon, color, amount, transactionCount, percentage];
}

class MonthlyTrendEntity extends Equatable {
  final String month;
  final double income;
  final double expenses;

  const MonthlyTrendEntity({
    required this.month,
    required this.income,
    required this.expenses,
  });

  double get net => income - expenses;

  @override
  List<Object?> get props => [month, income, expenses];
}
