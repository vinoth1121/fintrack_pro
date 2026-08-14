import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../../../../shared/widgets/states/app_states.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: Text('Notifications', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationListProvider.notifier).markAllAsRead(),
              child: Text('Mark all read', style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: state.status == NotificationListStatus.loading
          ? const Padding(padding: EdgeInsets.all(AppSpacing.base), child: AppShimmerList(itemCount: 5, itemHeight: 76))
          : state.notifications.isEmpty
              ? const AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications',
                  subtitle: 'You\'re all caught up! We\'ll notify you about budget alerts, bills, and goal progress.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    itemCount: state.notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final notification = state.notifications[i];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => ref.read(notificationListProvider.notifier).markAsRead(notification.id),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  ({IconData icon, Color color}) get _visual {
    return switch (notification.type) {
      NotificationType.budgetAlert => (icon: Icons.account_balance_wallet_rounded, color: AppColors.warning),
      NotificationType.goalMilestone => (icon: Icons.emoji_events_rounded, color: AppColors.savings),
      NotificationType.billReminder => (icon: Icons.repeat_rounded, color: const Color(0xFFE040FB)),
      NotificationType.aiInsight => (icon: Icons.auto_awesome_rounded, color: AppColors.primary),
      NotificationType.system => (icon: Icons.info_outline_rounded, color: AppColors.info),
    };
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;

    return Material(
      color: notification.isRead ? AppColors.darkCard : AppColors.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: notification.isRead ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(visual.icon, color: visual.color, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(notification.body, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary, height: 1.4)),
                    const SizedBox(height: 4),
                    Text(_timeAgo(notification.createdAt), style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
