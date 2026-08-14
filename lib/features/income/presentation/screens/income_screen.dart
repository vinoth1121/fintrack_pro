import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/income_entity.dart';
import '../providers/income_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(incomeListProvider);

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
          'Income',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.status == IncomeListStatus.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: AppShimmerList(itemCount: 5, itemHeight: 76),
            )
          : state.incomes.isEmpty
              ? AppEmptyState(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'No income recorded',
                  subtitle: 'Add your salary, freelance payments, or other income sources.',
                  actionLabel: 'Add Income',
                  accentColor: AppColors.income,
                  onAction: () => context.push('/income/add'),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(incomeListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: _IncomeSummaryCard(
                          total: state.totalAmount,
                          recurring: state.monthlyRecurring,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: AppSectionHeader(title: 'All Income'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...state.incomes.map((income) => _IncomeTile(
                        income: income,
                        onDelete: () => _confirmDelete(context, ref, income),
                      ),),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/income/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Income'),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.black87,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, IncomeEntity income) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Income?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This will permanently delete "${income.title}".',
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
              ref.read(incomeListProvider.notifier).deleteIncome(income.id);
              AppSnackbar.success(context, 'Income deleted.');
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ────────────────────────────────────────────────────────────

class _IncomeSummaryCard extends StatelessWidget {
  final double total;
  final double recurring;

  const _IncomeSummaryCard({required this.total, required this.recurring});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.incomeGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: Colors.black87, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Total Income',
                style: AppTypography.bodySmall.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _fmt.format(total),
            style: AppTypography.amountHero.copyWith(color: Colors.black87, fontSize: 38),
          ),
          const SizedBox(height: AppSpacing.base),
          Container(height: 0.5, color: Colors.black26),
          const SizedBox(height: AppSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recurring monthly',
                style: AppTypography.bodySmall.copyWith(color: Colors.black54),
              ),
              Text(
                _fmt.format(recurring),
                style: AppTypography.bodyMedium.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Income Tile ──────────────────────────────────────────────────────────────

class _IncomeTile extends StatelessWidget {
  final IncomeEntity income;
  final VoidCallback onDelete;

  const _IncomeTile({required this.income, required this.onDelete});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final color = income.category != null
        ? Color(int.parse(income.category!.color.replaceFirst('#', '0xFF')))
        : AppColors.income;

    return Dismissible(
      key: ValueKey(income.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 2),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(AppRadius.base)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(color: AppColors.darkBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(_iconFor(income.category?.icon), color: color, size: 20),
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
                          income.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (income.isRecurring) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.repeat_rounded, size: 12, color: AppColors.darkTextTertiary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${income.category?.name ?? 'Income'} · ${DateFormat.MMMd().format(income.date)}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
                  ),
                ],
              ),
            ),
            Text(
              '+${_fmt.format(income.amount)}',
              style: AppTypography.amountSmall.copyWith(color: AppColors.income, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? icon) {
    return switch (icon) {
      'work' => Icons.work_rounded,
      'code' => Icons.code_rounded,
      'trending_up' => Icons.trending_up_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'business' => Icons.business_center_rounded,
      _ => Icons.attach_money_rounded,
    };
  }
}
