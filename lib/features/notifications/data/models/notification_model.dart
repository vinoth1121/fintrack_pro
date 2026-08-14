import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        title: title,
        body: body,
        isRead: isRead,
        createdAt: createdAt,
        type: switch (type) {
          'BUDGET_ALERT' => NotificationType.budgetAlert,
          'GOAL_MILESTONE' => NotificationType.goalMilestone,
          'BILL_REMINDER' => NotificationType.billReminder,
          'AI_INSIGHT' => NotificationType.aiInsight,
          _ => NotificationType.system,
        },
      );
}

class PaginatedNotificationsModel {
  final List<NotificationModel> items;
  final int unreadCount;

  const PaginatedNotificationsModel({required this.items, required this.unreadCount});

  factory PaginatedNotificationsModel.fromJson(Map<String, dynamic> json) {
    return PaginatedNotificationsModel(
      items: (json['items'] as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList(),
      unreadCount: json['unreadCount'] as int,
    );
  }
}
