import '../../domain/entities/budget_entity.dart';
import '../../../expenses/data/models/expense_model.dart';

class BudgetModel {
  final String id;
  final String name;
  final CategoryModel? category;
  final double amount;
  final double spent;
  final String period;
  final DateTime startDate;
  final DateTime? endDate;
  final int alertAt;
  final bool isActive;
  final String? color;

  const BudgetModel({
    required this.id,
    required this.name,
    this.category,
    required this.amount,
    this.spent = 0,
    this.period = 'MONTHLY',
    required this.startDate,
    this.endDate,
    this.alertAt = 80,
    this.isActive = true,
    this.color,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        amount: (json['amount'] as num).toDouble(),
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        period: json['period'] as String? ?? 'MONTHLY',
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
        alertAt: json['alertAt'] as int? ?? 80,
        isActive: json['isActive'] as bool? ?? true,
        color: json['color'] as String?,
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (category != null) 'categoryId': category!.id,
        'amount': amount,
        'period': period,
        'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'alertAt': alertAt,
        if (color != null) 'color': color,
      };

  BudgetEntity toEntity() => BudgetEntity(
        id: id,
        name: name,
        category: category?.toEntity(),
        amount: amount,
        spent: spent,
        period: switch (period) {
          'WEEKLY' => BudgetPeriod.weekly,
          'YEARLY' => BudgetPeriod.yearly,
          _ => BudgetPeriod.monthly,
        },
        startDate: startDate,
        endDate: endDate,
        alertAt: alertAt,
        isActive: isActive,
        color: color,
      );
}
