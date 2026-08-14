import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';
import '../../data/repositories/notification_repository.dart';
import '../../../../core/errors/failures.dart';

enum NotificationListStatus { initial, loading, loaded, error }

class NotificationListState extends Equatable {
  final NotificationListStatus status;
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final Failure? failure;

  const NotificationListState({
    this.status = NotificationListStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.failure,
  });

  NotificationListState copyWith({
    NotificationListStatus? status,
    List<NotificationEntity>? notifications,
    int? unreadCount,
    Failure? failure,
  }) {
    return NotificationListState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, notifications, unreadCount, failure];
}

class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final NotificationRepository _repository;

  NotificationListNotifier(this._repository) : super(const NotificationListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: NotificationListStatus.loading);
    final result = await _repository.getNotifications();

    result.fold(
      (failure) => state = state.copyWith(
        status: NotificationListStatus.loaded,
        notifications: _mockNotifications(),
        unreadCount: _mockNotifications().where((n) => !n.isRead).length,
      ),
      (data) => state = state.copyWith(
        status: NotificationListStatus.loaded,
        notifications: data.items.map((m) => m.toEntity()).toList(),
        unreadCount: data.unreadCount,
      ),
    );
  }

  Future<void> markAsRead(String id) async {
    final target = state.notifications.firstWhere((n) => n.id == id, orElse: () => state.notifications.first);
    if (target.isRead) return;

    final updated = state.notifications.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    state = state.copyWith(notifications: updated, unreadCount: (state.unreadCount - 1).clamp(0, 999));

    await _repository.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);
    await _repository.markAllAsRead();
  }

  List<NotificationEntity> _mockNotifications() {
    final now = DateTime.now();
    return [
      NotificationEntity(
        id: '1', type: NotificationType.budgetAlert,
        title: 'Budget Alert: Shopping', body: 'You\'ve used 92% of your Shopping budget for this month.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      NotificationEntity(
        id: '2', type: NotificationType.billReminder,
        title: 'Netflix bills tomorrow', body: 'Your Netflix subscription (\$15.99) will be charged tomorrow.',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      NotificationEntity(
        id: '3', type: NotificationType.goalMilestone,
        title: 'Goal Milestone! 🎉', body: 'You\'ve reached 65% of your Emergency Fund goal.',
        isRead: true, createdAt: now.subtract(const Duration(days: 1)),
      ),
      NotificationEntity(
        id: '4', type: NotificationType.aiInsight,
        title: 'New AI Insight', body: 'Your dining expenses increased 18% compared to last month.',
        isRead: true, createdAt: now.subtract(const Duration(days: 2)),
      ),
      NotificationEntity(
        id: '5', type: NotificationType.system,
        title: 'Welcome to FinTrack Pro', body: 'Your account is set up. Start by adding your first expense.',
        isRead: true, createdAt: now.subtract(const Duration(days: 7)),
      ),
    ];
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((ref) {
  return NotificationListNotifier(ref.watch(notificationRepositoryProvider));
});
