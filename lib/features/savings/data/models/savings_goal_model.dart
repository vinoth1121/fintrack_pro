import '../../domain/entities/savings_goal_entity.dart';

class SavingsGoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String currency;
  final DateTime? deadline;
  final String? icon;
  final String? color;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.currency = 'USD',
    this.deadline,
    this.icon,
    this.color,
    this.status = 'ACTIVE',
    this.notes,
    required this.createdAt,
  });

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) => SavingsGoalModel(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'targetAmount': targetAmount,
        'currency': currency,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (notes != null) 'notes': notes,
      };

  SavingsGoalEntity toEntity() => SavingsGoalEntity(
        id: id,
        name: name,
        targetAmount: targetAmount,
        savedAmount: savedAmount,
        currency: currency,
        deadline: deadline,
        icon: icon,
        color: color,
        status: switch (status) {
          'COMPLETED' => GoalStatus.completed,
          'PAUSED' => GoalStatus.paused,
          'CANCELLED' => GoalStatus.cancelled,
          _ => GoalStatus.active,
        },
        notes: notes,
        createdAt: createdAt,
      );
}
