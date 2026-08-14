import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final String cycle;
  final DateTime nextBillingDate;
  final DateTime startDate;
  final String? category;
  final String? icon;
  final String? color;
  final String status;
  final String? notes;
  final String? url;
  final bool autoDetected;

  const SubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'USD',
    this.cycle = 'MONTHLY',
    required this.nextBillingDate,
    required this.startDate,
    this.category,
    this.icon,
    this.color,
    this.status = 'ACTIVE',
    this.notes,
    this.url,
    this.autoDetected = false,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        cycle: json['cycle'] as String? ?? 'MONTHLY',
        nextBillingDate: DateTime.parse(json['nextBillingDate'] as String),
        startDate: DateTime.parse(json['startDate'] as String),
        category: json['category'] as String?,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        notes: json['notes'] as String?,
        url: json['url'] as String?,
        autoDetected: json['autoDetected'] as bool? ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'amount': amount,
        'currency': currency,
        'cycle': cycle,
        'nextBillingDate': nextBillingDate.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        if (category != null) 'category': category,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (notes != null) 'notes': notes,
        if (url != null) 'url': url,
      };

  SubscriptionEntity toEntity() => SubscriptionEntity(
        id: id,
        name: name,
        amount: amount,
        currency: currency,
        cycle: switch (cycle) {
          'WEEKLY' => SubscriptionCycle.weekly,
          'QUARTERLY' => SubscriptionCycle.quarterly,
          'YEARLY' => SubscriptionCycle.yearly,
          _ => SubscriptionCycle.monthly,
        },
        nextBillingDate: nextBillingDate,
        startDate: startDate,
        category: category,
        icon: icon,
        color: color,
        status: switch (status) {
          'PAUSED' => SubscriptionStatus.paused,
          'CANCELLED' => SubscriptionStatus.cancelled,
          _ => SubscriptionStatus.active,
        },
        notes: notes,
        url: url,
        autoDetected: autoDetected,
      );
}
