import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/budget_entity.dart';
import '../providers/budget_provider.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetListProvider);

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
          'Budget',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.status == BudgetListStatus.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: AppShimmerList(itemCount: 5, itemHeight: 90),
            )
          : state.budgets.isEmpty
              ? AppEmptyState(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'No budgets set',
                  subtitle: 'Create category budgets to keep your spending on track.',
                  actionLabel: 'Create Budget',
                  accentColor: AppColors.budget,
                  onAction: () => _showAddBudgetSheet(context),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(budgetListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: _BudgetOverviewCard(state: state),
                      ),
                      if (state.overBudgetCount > 0) ...[
                        const SizedBox(height: AppSpacing.base),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                          child: _OverBudgetWarning(count: state.overBudgetCount),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                        child: AppSectionHeader(title: 'Category Budgets'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...state.budgets.map((budget) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: AppSpacing.xs,
                        ),
                        child: _BudgetCard(
                          budget: budget,
                          onDelete: () => _confirmDelete(context, ref, budget),
                        ),
                      ),),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Budget'),
        backgroundColor: AppColors.budget,
        foregroundColor: Colors.black87,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BudgetEntity budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Budget?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This will permanently delete "${budget.name}".',
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
              ref.read(budgetListProvider.notifier).deleteBudget(budget.id);
              AppSnackbar.success(context, 'Budget deleted.');
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddBudgetSheet(),
    );
  }
}

// ─── Overview Card ────────────────────────────────────────────────────────────

class _BudgetOverviewCard extends StatelessWidget {
  final BudgetListState state;
  const _BudgetOverviewCard({required this.state});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  Color get _ringColor {
    if (state.overallPercentage >= 100) return AppColors.error;
    if (state.overallPercentage >= 80) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: (state.overallPercentage / 100).clamp(0, 1),
                    strokeWidth: 8,
                    backgroundColor: AppColors.darkBorder,
                    valueColor: AlwaysStoppedAnimation(_ringColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.overallPercentage.toStringAsFixed(0)}%',
                      style: AppTypography.titleMedium.copyWith(
                        color: _ringColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('used', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewRow(label: 'Budgeted', value: _fmt.format(state.totalBudgeted)),
                const SizedBox(height: AppSpacing.sm),
                _OverviewRow(label: 'Spent', value: _fmt.format(state.totalSpent), valueColor: _ringColor),
                const SizedBox(height: AppSpacing.sm),
                Container(height: 0.5, color: AppColors.darkDivider),
                const SizedBox(height: AppSpacing.sm),
                _OverviewRow(
                  label: 'Remaining',
                  value: _fmt.format(state.totalBudgeted - state.totalSpent),
                  valueColor: AppColors.darkTextPrimary,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _OverviewRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: valueColor ?? AppColors.darkTextSecondary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Over Budget Warning ──────────────────────────────────────────────────────

class _OverBudgetWarning extends StatelessWidget {
  final int count;
  const _OverBudgetWarning({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'budget is' : 'budgets are'} over the limit this period.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Budget Card ──────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetEntity budget;
  final VoidCallback onDelete;

  const _BudgetCard({required this.budget, required this.onDelete});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  Color get _color {
    switch (budget.status) {
      case BudgetStatus.over:
        return AppColors.error;
      case BudgetStatus.nearLimit:
        return AppColors.warning;
      case BudgetStatus.healthy:
        return budget.category != null
            ? Color(int.parse(budget.category!.color.replaceFirst('#', '0xFF')))
            : AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(
            color: budget.isOverBudget ? AppColors.error.withValues(alpha: 0.4) : AppColors.darkBorder,
            width: budget.isOverBudget ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(_iconFor(budget.category?.icon), color: _color, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    budget.name,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (budget.isOverBudget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'OVER',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt.format(budget.spent)} of ${_fmt.format(budget.amount)}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
                ),
                Text(
                  '${budget.percentageUsed.toStringAsFixed(0)}%',
                  style: AppTypography.labelMedium.copyWith(color: _color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: (budget.percentageUsed / 100).clamp(0, 1),
                backgroundColor: AppColors.darkBorder,
                valueColor: AlwaysStoppedAnimation(_color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? icon) {
    return switch (icon) {
      'restaurant' => Icons.restaurant_rounded,
      'car' => Icons.directions_car_rounded,
      'bag' => Icons.shopping_bag_rounded,
      'movie' => Icons.movie_rounded,
      'flash' => Icons.flash_on_rounded,
      'health' => Icons.favorite_rounded,
      'book' => Icons.menu_book_rounded,
      'home' => Icons.home_rounded,
      'flight' => Icons.flight_rounded,
      _ => Icons.category_rounded,
    };
  }
}

// ─── Add Budget Sheet ─────────────────────────────────────────────────────────

class _AddBudgetSheet extends ConsumerStatefulWidget {
  const _AddBudgetSheet();

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final formState = ref.read(addBudgetProvider);
    if (formState.selectedCategory == null) {
      AppSnackbar.warning(context, 'Please select a category.');
      return;
    }

    final success = await ref.read(addBudgetProvider.notifier).submit(
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text),
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnackbar.success(context, 'Budget created successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addBudgetProvider);

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
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.darkBorder,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'New Budget',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _nameController,
                  label: 'Budget Name',
                  hint: 'e.g. Groceries',
                  prefixIcon: Icons.label_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.base),
                AppAmountField(controller: _amountController),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Category',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.darkTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: DefaultCategories.expense.map((cat) {
                    final isSelected = formState.selectedCategory?.id == cat.id;
                    final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => ref.read(addBudgetProvider.notifier).selectCategory(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.darkCardElevated,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: isSelected ? color : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
                        ),
                        child: Text(
                          cat.name,
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected ? color : AppColors.darkTextSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppPrimaryButton(
                  label: 'Create Budget',
                  isLoading: formState.isLoading,
                  color: AppColors.budget,
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
