import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/expense_entity.dart';
import '../providers/expense_provider.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(expenseListProvider);
    final expense = listState.expenses.where((e) => e.id == expenseId).firstOrNull;

    if (expense == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Expense not found',
          subtitle: 'This expense may have been deleted.',
        ),
      );
    }

    final color = expense.category != null
        ? Color(int.parse(expense.category!.color.replaceFirst('#', '0xFF')))
        : AppColors.darkTextTertiary;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref, expense),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          // ── Hero Amount ──────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(expense.category?.icon), color: color, size: 28),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  '-${_fmt.format(expense.amount)}',
                  style: AppTypography.amountHero.copyWith(color: AppColors.expense),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  expense.title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ── Detail Card ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.darkBorder, width: 0.5),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: expense.category?.name ?? 'Uncategorized',
                  valueColor: color,
                ),
                _divider(),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: DateFormat('EEEE, MMM d, yyyy').format(expense.date),
                ),
                if (expense.paymentMethod != null) ...[
                  _divider(),
                  _DetailRow(
                    icon: Icons.credit_card_rounded,
                    label: 'Payment Method',
                    value: expense.paymentMethod!,
                  ),
                ],
                if (expense.isRecurring) ...[
                  _divider(),
                  const _DetailRow(
                    icon: Icons.repeat_rounded,
                    label: 'Recurring',
                    value: 'Yes',
                  ),
                ],
                if (expense.location != null) ...[
                  _divider(),
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: expense.location!,
                  ),
                ],
              ],
            ),
          ),

          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: AppColors.darkBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextTertiary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    expense.notes!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.darkTextSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        color: AppColors.darkDivider,
        thickness: 0.5,
        height: 1,
        indent: AppSpacing.base,
        endIndent: AppSpacing.base,
      );

  void _confirmDelete(BuildContext context, WidgetRef ref, ExpenseEntity expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Expense?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This will permanently delete "${expense.title}".',
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
              ref.read(expenseListProvider.notifier).deleteExpense(expense.id);
              context.pop();
              AppSnackbar.success(context, 'Expense deleted.');
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.darkTextTertiary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
          const Spacer(),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: valueColor ?? AppColors.darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
