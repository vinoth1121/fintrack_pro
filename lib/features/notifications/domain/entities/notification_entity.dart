import 'package:equatable/equatable.dart';

enum NotificationType { budgetAlert, goalMilestone, billReminder, aiInsight, system }

class NotificationEntity extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id, type: type, title: title, body: body,
      isRead: isRead ?? this.isRead, createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, type, title, body, isRead, createdAt];
}
