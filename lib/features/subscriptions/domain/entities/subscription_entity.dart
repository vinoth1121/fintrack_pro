import 'package:equatable/equatable.dart';

enum SubscriptionCycle { weekly, monthly, quarterly, yearly }
enum SubscriptionStatus { active, paused, cancelled }

class SubscriptionEntity extends Equatable {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final SubscriptionCycle cycle;
  final DateTime nextBillingDate;
  final DateTime startDate;
  final String? category;
  final String? icon;
  final String? color;
  final SubscriptionStatus status;
  final String? notes;
  final String? url;
  final bool autoDetected;

  const SubscriptionEntity({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'USD',
    this.cycle = SubscriptionCycle.monthly,
    required this.nextBillingDate,
    required this.startDate,
    this.category,
    this.icon,
    this.color,
    this.status = SubscriptionStatus.active,
    this.notes,
    this.url,
    this.autoDetected = false,
  });

  /// Normalizes any billing cycle to a monthly-equivalent cost for comparison
  double get monthlyEquivalent {
    return switch (cycle) {
      SubscriptionCycle.weekly => amount * 4.33,
      SubscriptionCycle.monthly => amount,
      SubscriptionCycle.quarterly => amount / 3,
      SubscriptionCycle.yearly => amount / 12,
    };
  }

  int get daysUntilBilling => nextBillingDate.difference(DateTime.now()).inDays;

  bool get isBillingSoon => daysUntilBilling <= 3 && daysUntilBilling >= 0;

  String get cycleLabel => switch (cycle) {
    SubscriptionCycle.weekly => 'week',
    SubscriptionCycle.monthly => 'month',
    SubscriptionCycle.quarterly => 'quarter',
    SubscriptionCycle.yearly => 'year',
  };

  @override
  List<Object?> get props => [
    id, name, amount, currency, cycle, nextBillingDate, startDate,
    category, icon, color, status, notes, url, autoDetected,
  ];
}
