import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../providers/fintrack_provider.dart';

/// Notifications screen — written from scratch.
///
/// Two things this does that the previous version didn't:
///   1. Every notification pushed through [FinTrackNotifier.pushNotification]
///      now also fires a real OS-level notification via [NotificationService]
///      (see the provider), so "Notifications" means an actual push, not
///      just an item appearing in an in-app list.
///   2. This screen owns the permission flow: if OS notification permission
///      hasn't been granted, it shows a banner to request it, and offers a
///      "Send test notification" action so the person can confirm it's
///      actually working end-to-end.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _Filter { all, unread, alerts, ai }

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Filter _filter = _Filter.all;
  bool _generatingSummary = false;
  bool? _permissionGranted; // null while checking

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    await NotificationService.instance.init();
    final granted = await NotificationService.instance.hasPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    if (!granted) {
      showAppToast(
        context,
        'Notifications are off. Enable them in your device Settings to get budget and bill alerts.',
        kind: ToastKind.info,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showNow(
      title: 'FinTrack Pro',
      body: 'Notifications are working! You\'ll get alerts like this for budgets, bills, and AI insights.',
    );
    if (!mounted) return;
    showAppToast(context, 'Test notification sent — check your notification shade.');
  }

  Future<void> _generateWeeklySummary() async {
    setState(() => _generatingSummary = true);
    try {
      final s = ref.read(fintrackProvider);
      final categoryNames = {for (final c in s.categories) c.id: c.name};
      final summary = await AiRepository.weeklySummary(
        transactions: s.transactions,
        currency: s.profile.baseCurrency,
        categoryNameMap: categoryNames,
      );
      if (summary == null) {
        if (mounted) {
          showAppToast(context, 'Could not generate a summary right now — check your connection.', kind: ToastKind.error);
        }
        return;
      }
      final body = summary.body +
          (summary.highlights.isNotEmpty
              ? '\n\n${summary.highlights.map((h) => '• $h').join('\n')}'
              : '');
      await ref.read(fintrackProvider.notifier).pushNotification(
        AppNotification(
          id: uid('notif_'),
          title: summary.title,
          body: body,
          kind: NotificationKind.ai,
          read: false,
          createdAt: DateTime.now(),
          action: const NotificationAction(label: 'View insights', view: 'insights'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  List<AppNotification> _visible(List<AppNotification> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.unread:
        return all.where((n) => !n.read).toList();
      case _Filter.alerts:
        return all.where((n) =>
          n.kind == NotificationKind.warning || n.kind == NotificationKind.error,).toList();
      case _Filter.ai:
        return all.where((n) => n.kind == NotificationKind.ai).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final s = ref.watch(fintrackProvider);
    final all = s.notifications;
    final unreadCount = all.where((n) => !n.read).length;
    final visible = _visible(all)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_permissionGranted == false) _PermissionBanner(onEnable: _requestPermission),

          // Header actions
          Row(
            children: [
              Expanded(
                child: Text(
                  unreadCount > 0 ? '$unreadCount unread' : 'You\'re all caught up',
                  style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground),
                ),
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: () => ref.read(fintrackProvider.notifier).markAllRead(),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'All', selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Unread', selected: _filter == _Filter.unread, onTap: () => setState(() => _filter = _Filter.unread)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Alerts', selected: _filter == _Filter.alerts, onTap: () => setState(() => _filter = _Filter.alerts)),
                const SizedBox(width: 8),
                _FilterChip(label: 'AI insights', selected: _filter == _Filter.ai, onTap: () => setState(() => _filter = _Filter.ai)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  onPressed: _generatingSummary ? null : _generateWeeklySummary,
                  child: _generatingSummary
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Generate weekly AI summary'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Send a test notification',
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.notifications_active_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (visible.isEmpty)
            _EmptyState(filter: _filter)
          else
            ...visible.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationCard(
                notification: n,
                onTap: () {
                  if (!n.read) {
                    ref.read(fintrackProvider.notifier).markNotificationRead(n.id);
                  }
                  if (n.action != null) context.go('/${n.action!.view}');
                },
                onDismiss: () => ref.read(fintrackProvider.notifier).markNotificationRead(n.id),
              ),
            ),),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onEnable;
  const _PermissionBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.notifications_off_outlined, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Turn on notifications to get real budget alerts, bill reminders, and AI insights on your phone.',
                style: AppTypography.body(context, size: 12),
              ),
            ),
            const SizedBox(width: 8),
            GradientButton(onPressed: onEnable, child: const Text('Enable')),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : l.surface2.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: l.border),
        ),
        child: Text(
          label,
          style: AppTypography.label(context, size: 13).copyWith(
            color: selected ? Colors.white : l.foreground,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotificationCard({required this.notification, required this.onTap, required this.onDismiss});

  (IconData, Color) _iconFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.success:
        return (Icons.check_circle_outline, AppColors.success);
      case NotificationKind.warning:
        return (Icons.warning_amber_outlined, AppColors.warning);
      case NotificationKind.error:
        return (Icons.error_outline, AppColors.error);
      case NotificationKind.ai:
        return (Icons.auto_awesome, AppColors.iris);
      case NotificationKind.info:
        return (Icons.info_outline, AppColors.iris);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final (icon, color) = _iconFor(notification.kind);
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.check, color: AppColors.success),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.heading(context, size: 14).copyWith(
                              fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: const BoxDecoration(color: AppColors.iris, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(notification.body, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground)),
                    const SizedBox(height: 6),
                    Text(_relativeTime(notification.createdAt), style: AppTypography.label(context, size: 11).copyWith(color: l.mutedForeground)),
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

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final message = switch (filter) {
      _Filter.all => 'No notifications yet',
      _Filter.unread => 'You\'re all caught up',
      _Filter.alerts => 'No alerts right now',
      _Filter.ai => 'No AI insights yet — try generating a weekly summary',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.notifications_none_outlined, size: 40, color: l.mutedForeground),
          const SizedBox(height: 12),
          Text(message, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground)),
        ],
      ),
    );
  }
}
