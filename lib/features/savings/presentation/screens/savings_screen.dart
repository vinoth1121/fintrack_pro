import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/savings_goal_entity.dart';
import '../providers/savings_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savingsListProvider);

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
          'Savings Goals',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.status == SavingsListStatus.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: AppShimmerList(itemCount: 4, itemHeight: 140),
            )
          : state.goals.isEmpty
              ? AppEmptyState(
                  icon: Icons.savings_rounded,
                  title: 'No savings goals yet',
                  subtitle: 'Set a goal and start building toward what matters to you.',
                  actionLabel: 'Create Goal',
                  accentColor: AppColors.savings,
                  onAction: () => context.push('/savings/add'),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(savingsListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: _SavingsSummaryCard(
                          totalSaved: state.totalSaved,
                          totalTarget: state.totalTarget,
                          goalCount: state.activeGoals.length,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (state.activeGoals.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                          child: AppSectionHeader(title: 'Active Goals'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...state.activeGoals.map((goal) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                          child: _GoalCard(
                            goal: goal,
                            onContribute: () => _showContributeSheet(context, ref, goal),
                            onDelete: () => _confirmDelete(context, ref, goal),
                          ),
                        ),),
                      ],
                      if (state.completedGoals.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                          child: AppSectionHeader(title: 'Completed 🎉'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...state.completedGoals.map((goal) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                          child: _GoalCard(
                            goal: goal,
                            onContribute: null,
                            onDelete: () => _confirmDelete(context, ref, goal),
                          ),
                        ),),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/savings/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal'),
        backgroundColor: AppColors.savings,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavingsGoalEntity goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Goal?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This will permanently delete "${goal.name}" and its progress.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(savingsListProvider.notifier).deleteGoal(goal.id);
              AppSnackbar.success(context, 'Goal deleted.');
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showContributeSheet(BuildContext context, WidgetRef ref, SavingsGoalEntity goal) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to "${goal.name}"',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppAmountField(controller: controller),
                const SizedBox(height: AppSpacing.xl),
                AppPrimaryButton(
                  label: 'Add Contribution',
                  color: AppColors.savings,
                  onTap: () async {
                    final amount = double.tryParse(controller.text);
                    if (amount == null || amount <= 0) {
                      AppSnackbar.warning(context, 'Enter a valid amount.');
                      return;
                    }
                    await ref.read(savingsListProvider.notifier).contribute(goal.id, amount);
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppSnackbar.success(context, 'Contribution added!');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ────────────────────────────────────────────────────────────

class _SavingsSummaryCard extends StatelessWidget {
  final double totalSaved;
  final double totalTarget;
  final int goalCount;

  const _SavingsSummaryCard({required this.totalSaved, required this.totalTarget, required this.goalCount});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final pct = totalTarget > 0 ? (totalSaved / totalTarget * 100).clamp(0, 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF0E0E24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.savings.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: AppColors.savings, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Total Saved', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_fmt.format(totalSaved), style: AppTypography.amountHero.copyWith(color: AppColors.darkTextPrimary, fontSize: 36)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'of ${_fmt.format(totalTarget)} across $goalCount active goals',
            style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
          ),
          const SizedBox(height: AppSpacing.base),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: AppColors.darkBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.savings),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final SavingsGoalEntity goal;
  final VoidCallback? onContribute;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onContribute, required this.onDelete});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final color = goal.color != null
        ? Color(int.parse(goal.color!.replaceFirst('#', '0xFF')))
        : AppColors.savings;

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(color: AppColors.darkBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(_iconFor(goal.icon), color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                      if (goal.isCompleted)
                        Text('Goal reached! 🎉', style: AppTypography.bodySmall.copyWith(color: AppColors.success))
                      else if (goal.daysRemaining != null)
                        Text('${goal.daysRemaining} days left', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary))
                      else
                        Text('No deadline set', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                    ],
                  ),
                ),
                if (goal.isCompleted)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_fmt.format(goal.savedAmount)} of ${_fmt.format(goal.targetAmount)}', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary)),
                Text('${goal.percentageComplete.toStringAsFixed(0)}%', style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: goal.percentageComplete / 100,
                backgroundColor: AppColors.darkBorder,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            if (goal.suggestedDailyContribution != null && !goal.isCompleted) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Save ${_fmt.format(goal.suggestedDailyContribution!)}/day to hit your goal',
                style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10),
              ),
            ],
            if (onContribute != null) ...[
              const SizedBox(height: AppSpacing.base),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onContribute,
                  icon: Icon(Icons.add_rounded, size: 16, color: color),
                  label: Text('Add Money', style: TextStyle(color: color)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? icon) {
    return switch (icon) {
      'shield' => Icons.shield_rounded,
      'flight' => Icons.flight_rounded,
      'car' => Icons.directions_car_rounded,
      'home' => Icons.home_rounded,
      'favorite' => Icons.favorite_rounded,
      'book' => Icons.menu_book_rounded,
      'devices' => Icons.devices_rounded,
      _ => Icons.flag_rounded,
    };
  }
}
