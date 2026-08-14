import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/expense_entity.dart';
import '../providers/expense_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(expenseListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseListProvider);

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
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(expenseListProvider.notifier).setSearch(v),
              )
            : Text(
                'Expenses',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_none_rounded),
            tooltip: 'Add by voice',
            onPressed: () => context.push(AppRoutes.voiceExpense),
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan receipt',
            onPressed: () => context.push(AppRoutes.scanReceipt),
          ),
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                ref.read(expenseListProvider.notifier).setSearch('');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          if (state.expenses.isNotEmpty) _ExpenseSummaryBar(total: state.totalAmount),

          // Category chips
          _CategoryFilterChips(
            selected: state.categoryFilter,
            onSelect: (id) => ref.read(expenseListProvider.notifier).setCategoryFilter(id),
          ),

          // List
          Expanded(
            child: state.status == ExpenseListStatus.loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.base),
                    child: AppShimmerList(itemCount: 6, itemHeight: 64),
                  )
                : state.expenses.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No expenses yet',
                        subtitle: 'Start tracking your spending by adding your first expense.',
                        actionLabel: 'Add Expense',
                        accentColor: AppColors.expense,
                        onAction: () => context.push('/expenses/add'),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(expenseListProvider.notifier).load(),
                        color: AppColors.primary,
                        backgroundColor: AppColors.darkCard,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 100),
                          children: _buildGroupedList(state),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  List<Widget> _buildGroupedList(ExpenseListState state) {
    final grouped = state.groupedByDate;
    final widgets = <Widget>[];

    grouped.forEach((dateLabel, expenses) {
      final groupTotal = expenses.fold(0.0, (sum, e) => sum + e.amount);
      widgets.add(_DateGroupHeader(label: dateLabel, total: groupTotal));
      for (final expense in expenses) {
        widgets.add(_ExpenseListTile(
          expense: expense,
          onDelete: () => _confirmDelete(expense),
        ),);
      }
    });

    if (state.status == ExpenseListStatus.loadingMore) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.base),
        child: Center(child: AppLoadingState()),
      ),);
    }

    return widgets;
  }

  void _confirmDelete(ExpenseEntity expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text(
          'Delete Expense?',
          style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary),
        ),
        content: Text(
          'This will permanently delete "${expense.title}". This action cannot be undone.',
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
              AppSnackbar.success(context, 'Expense deleted.');
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(
        onApply: (start, end) {
          ref.read(expenseListProvider.notifier).setDateRange(start, end);
        },
      ),
    );
  }
}

// ─── Summary Bar ─────────────────────────────────────────────────────────────

class _ExpenseSummaryBar extends StatelessWidget {
  final double total;
  const _ExpenseSummaryBar({required this.total});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: AppColors.expenseGradient,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Spent', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(
                _fmt.format(total),
                style: AppTypography.amountMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Icon(Icons.trending_down_rounded, color: Colors.white, size: 32),
        ],
      ),
    );
  }
}

// ─── Category Filter Chips ────────────────────────────────────────────────────

class _CategoryFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _CategoryFilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        children: [
          _Chip(label: 'All', isSelected: selected == null, onTap: () => onSelect(null)),
          ...DefaultCategories.expense.map((cat) => Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: _Chip(
              label: cat.name,
              isSelected: selected == cat.id,
              color: Color(int.parse(cat.color.replaceFirst('#', '0xFF'))),
              onTap: () => onSelect(cat.id),
            ),
          ),),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.18) : AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: isSelected ? c : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? c : AppColors.darkTextSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Date Group Header ────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  final String label;
  final double total;

  const _DateGroupHeader({required this.label, required this.total});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.darkTextTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            _fmt.format(total),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expense Tile ────────────────────────────────────────────────────────────

class _ExpenseListTile extends StatelessWidget {
  final ExpenseEntity expense;
  final VoidCallback onDelete;

  const _ExpenseListTile({required this.expense, required this.onDelete});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final color = expense.category != null
        ? Color(int.parse(expense.category!.color.replaceFirst('#', '0xFF')))
        : AppColors.darkTextTertiary;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // Deletion handled via dialog
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).push('/expenses/${expense.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(_iconFor(expense.category?.icon), color: color, size: 20),
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
                              expense.title,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.darkTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (expense.isRecurring) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.repeat_rounded, size: 12, color: AppColors.darkTextTertiary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expense.category?.name ?? 'Uncategorized',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${_fmt.format(expense.amount)}',
                  style: AppTypography.amountSmall.copyWith(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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

// ─── Filter Sheet ────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final void Function(DateTime?, DateTime?) onApply;
  const _FilterSheet({required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              'Filter by Date',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _range = picked);
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(_range == null
                  ? 'Select date range'
                  : '${DateFormat.MMMd().format(_range!.start)} - ${DateFormat.MMMd().format(_range!.end)}',),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onApply(null, null);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_range?.start, _range?.end);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
