import 'package:equatable/equatable.dart';

enum GoalStatus { active, completed, paused, cancelled }

class SavingsGoalEntity extends Equatable {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String currency;
  final DateTime? deadline;
  final String? icon;
  final String? color;
  final GoalStatus status;
  final String? notes;
  final DateTime createdAt;

  const SavingsGoalEntity({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.currency = 'USD',
    this.deadline,
    this.icon,
    this.color,
    this.status = GoalStatus.active,
    this.notes,
    required this.createdAt,
  });

  double get percentageComplete =>
      targetAmount > 0 ? (savedAmount / targetAmount * 100).clamp(0, 100) : 0;

  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  int? get daysRemaining {
    if (deadline == null) return null;
    final diff = deadline!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Suggested amount to save per day/week/month to hit the deadline
  double? get suggestedDailyContribution {
    final days = daysRemaining;
    if (days == null || days <= 0) return null;
    return remaining / days;
  }

  bool get isCompleted => status == GoalStatus.completed || savedAmount >= targetAmount;

  @override
  List<Object?> get props => [
    id, name, targetAmount, savedAmount, currency, deadline,
    icon, color, status, notes, createdAt,
  ];
}

// ─── Preset goal templates for quick creation ───────────────────────────────

class GoalTemplate {
  final String name;
  final String icon;
  final String color;
  const GoalTemplate({required this.name, required this.icon, required this.color});
}

abstract final class GoalTemplates {
  static const all = [
    GoalTemplate(name: 'Emergency Fund', icon: 'shield', color: '#00D4A8'),
    GoalTemplate(name: 'Vacation', icon: 'flight', color: '#2196F3'),
    GoalTemplate(name: 'New Car', icon: 'car', color: '#FF9800'),
    GoalTemplate(name: 'Home Down Payment', icon: 'home', color: '#6C63FF'),
    GoalTemplate(name: 'Wedding', icon: 'favorite', color: '#E040FB'),
    GoalTemplate(name: 'Education', icon: 'book', color: '#9C27B0'),
    GoalTemplate(name: 'New Gadget', icon: 'devices', color: '#00BCD4'),
    GoalTemplate(name: 'Custom Goal', icon: 'flag', color: '#607D8B'),
  ];
}
