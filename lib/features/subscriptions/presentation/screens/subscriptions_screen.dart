import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/subscription_entity.dart';
import '../providers/subscription_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionListProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => ShellScaffoldData.of(context)?.openDrawer(),
          ),
        ),
        title: Text(
          'Subscriptions',
          style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: state.status == SubscriptionListStatus.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: AppShimmerList(itemCount: 5, itemHeight: 76),
            )
          : state.subscriptions.isEmpty
              ? AppEmptyState(
                  icon: Icons.repeat_rounded,
                  title: 'No subscriptions tracked',
                  subtitle: 'Add your recurring subscriptions to see your true monthly cost.',
                  actionLabel: 'Add Subscription',
                  accentColor: const Color(0xFFE040FB),
                  onAction: () => _showAddSheet(context),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(subscriptionListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: _CostSummaryCard(monthlyTotal: state.monthlyTotal, yearlyTotal: state.yearlyTotal, count: state.active.length),
                      ),
                      if (state.upcomingSoon.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.base),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                          child: _UpcomingBillingBanner(subscriptions: state.upcomingSoon),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: AppSectionHeader(title: 'All Subscriptions'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...state.active.map((sub) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                        child: _SubscriptionTile(
                          subscription: sub,
                          onCancel: () => _confirmCancel(context, ref, sub),
                        ),
                      ),),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Sub'),
        backgroundColor: const Color(0xFFE040FB),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, SubscriptionEntity sub) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Cancel Subscription?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This marks "${sub.name}" as cancelled and removes it from your monthly cost.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(subscriptionListProvider.notifier).cancelSubscription(sub.id);
              AppSnackbar.success(context, 'Subscription cancelled.');
            },
            child: Text('Cancel It', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddSubscriptionSheet(),
    );
  }
}

// ─── Cost Summary Card ────────────────────────────────────────────────────────

class _CostSummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final double yearlyTotal;
  final int count;

  const _CostSummaryCard({required this.monthlyTotal, required this.yearlyTotal, required this.count});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly Cost', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(_fmt.format(monthlyTotal), style: AppTypography.amountLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xs),
                Text('$count active · ${_fmt.format(yearlyTotal)}/year', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.repeat_rounded, color: Colors.white, size: 36),
        ],
      ),
    );
  }
}

// ─── Upcoming Billing Banner ───────────────────────────────────────────────────

class _UpcomingBillingBanner extends StatelessWidget {
  final List<SubscriptionEntity> subscriptions;
  const _UpcomingBillingBanner({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${subscriptions.length} ${subscriptions.length == 1 ? 'subscription bills' : 'subscriptions bill'} within 3 days',
              style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subscription Tile ─────────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  final SubscriptionEntity subscription;
  final VoidCallback onCancel;

  const _SubscriptionTile({required this.subscription, required this.onCancel});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final color = subscription.color != null
        ? Color(int.parse(subscription.color!.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return GestureDetector(
      onLongPress: onCancel,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(
            color: subscription.isBillingSoon ? AppColors.warning.withValues(alpha: 0.4) : AppColors.darkBorder,
            width: subscription.isBillingSoon ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(_iconFor(subscription.icon), color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subscription.name,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subscription.autoDetected) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subscription.daysUntilBilling == 0
                        ? 'Bills today'
                        : subscription.daysUntilBilling == 1
                            ? 'Bills tomorrow'
                            : 'Bills in ${subscription.daysUntilBilling} days',
                    style: AppTypography.bodySmall.copyWith(
                      color: subscription.isBillingSoon ? AppColors.warning : AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt.format(subscription.amount), style: AppTypography.amountSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                Text('/${subscription.cycleLabel}', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? icon) {
    return switch (icon) {
      'tv' => Icons.tv_rounded,
      'music' => Icons.music_note_rounded,
      'design' => Icons.brush_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'cloud' => Icons.cloud_rounded,
      'fitness' => Icons.fitness_center_rounded,
      _ => Icons.repeat_rounded,
    };
  }
}

// ─── Add Subscription Sheet ────────────────────────────────────────────────────

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  static const _cycles = [
    (SubscriptionCycle.weekly, 'Weekly'),
    (SubscriptionCycle.monthly, 'Monthly'),
    (SubscriptionCycle.quarterly, 'Quarterly'),
    (SubscriptionCycle.yearly, 'Yearly'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref.read(addSubscriptionProvider.notifier).submit(
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text),
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnackbar.success(context, 'Subscription added.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addSubscriptionProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Subscription', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _nameController,
                  label: 'Service Name',
                  hint: 'e.g. Netflix, Spotify',
                  prefixIcon: Icons.subscriptions_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.base),
                AppAmountField(controller: _amountController),
                const SizedBox(height: AppSpacing.base),
                Text('Billing Cycle', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: _cycles.map((c) {
                    final isSelected = formState.cycle == c.$1;
                    return GestureDetector(
                      onTap: () => ref.read(addSubscriptionProvider.notifier).selectCycle(c.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE040FB).withValues(alpha: 0.18) : AppColors.darkCardElevated,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: isSelected ? const Color(0xFFE040FB) : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
                        ),
                        child: Text(
                          c.$2,
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected ? const Color(0xFFE040FB) : AppColors.darkTextSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppPrimaryButton(
                  label: 'Add Subscription',
                  isLoading: formState.isLoading,
                  color: const Color(0xFFE040FB),
                  onTap: _onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
