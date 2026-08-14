import 'package:equatable/equatable.dart';
import '../../../expenses/domain/entities/expense_entity.dart';

enum BudgetPeriod { weekly, monthly, yearly }

class BudgetEntity extends Equatable {
  final String id;
  final String name;
  final CategoryEntity? category;
  final double amount;
  final double spent;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final int alertAt;
  final bool isActive;
  final String? color;

  const BudgetEntity({
    required this.id,
    required this.name,
    this.category,
    required this.amount,
    this.spent = 0,
    this.period = BudgetPeriod.monthly,
    required this.startDate,
    this.endDate,
    this.alertAt = 80,
    this.isActive = true,
    this.color,
  });

  double get remaining => amount - spent;
  double get percentageUsed => amount > 0 ? (spent / amount * 100).clamp(0, 999) : 0;
  bool get isOverBudget => spent > amount;
  bool get isNearLimit => percentageUsed >= alertAt;

  BudgetStatus get status {
    if (isOverBudget) return BudgetStatus.over;
    if (isNearLimit) return BudgetStatus.nearLimit;
    return BudgetStatus.healthy;
  }

  @override
  List<Object?> get props => [
    id, name, category, amount, spent, period, startDate, endDate, alertAt, isActive, color,
  ];
}

enum BudgetStatus { healthy, nearLimit, over }
