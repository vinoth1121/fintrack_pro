import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';
import 'add_transaction_sheet.dart';

/// Transactions list screen — shared by Expenses and Income tabs.
/// Mirrors the web `views/transactions.tsx`: header summary card, filter bar
/// (search + category + date range), grouped-by-date list, transaction detail
/// dialog, and a FAB that opens the AddTransactionSheet.
class TransactionsScreen extends ConsumerWidget {
  final TxType type;
  const TransactionsScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TransactionsBody(type: type);
  }
}

class _TransactionsBody extends ConsumerStatefulWidget {
  final TxType type;
  const _TransactionsBody({required this.type});

  @override
  ConsumerState<_TransactionsBody> createState() => _TransactionsBodyState();
}

class _TransactionsBodyState extends ConsumerState<_TransactionsBody> {
  String _search = '';
  String _categoryId = 'all';
  String _range = '30'; // 7 | 30 | 90 | all

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final l = context.lumina;
    final currency = s.profile.baseCurrency;
    final isExpense = widget.type == TxType.expense;

    final availableCats = s.categories.where((c) {
      return isExpense
          ? c.kind == CategoryKind.expense || c.kind == CategoryKind.both
          : c.kind == CategoryKind.income || c.kind == CategoryKind.both;
    }).toList();

    // Filter transactions
    final now = DateTime.now();
    final DateTime? fromDate = _range == 'all'
        ? null
        : DateTime(now.year, now.month, now.day).subtract(Duration(days: int.parse(_range)));

    final filtered = s.transactions.where((tx) {
      if (tx.type != widget.type) return false;
      if (_categoryId != 'all' && tx.categoryId != _categoryId) return false;
      if (fromDate != null && tx.date.isBefore(fromDate)) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.toLowerCase();
        final cat = s.categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => s.categories.last,
        );
        final hay = '${tx.merchant ?? ''} ${tx.note ?? ''} ${cat.name}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = filtered.fold<double>(0, (a, t) => a + t.amount);

    // Group by date
    final groups = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = formatDate(tx.date, style: 'long');
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final rangeLabel = _range == 'all'
        ? t.tx.allTime
        : _range == '7'
            ? t.tx.last7
            : _range == '30'
                ? t.tx.last30
                : t.tx.last90;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header summary card ──────────────────────────────
              _HeaderCard(
                title: isExpense ? t.tx.totalExpenses : t.tx.totalIncome,
                rangeLabel: rangeLabel,
                total: total,
                count: filtered.length,
                currency: currency,
                isExpense: isExpense,
                addLabel: isExpense ? t.tx.addExpense : t.tx.addIncome,
                onAdd: () => AddTransactionSheet.show(context, initialType: widget.type),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
              const SizedBox(height: 16),

              // ── Filter bar ───────────────────────────────────────
              _FilterBar(
                search: _search,
                onSearch: (v) => setState(() => _search = v),
                categoryId: _categoryId,
                onCategory: (v) => setState(() => _categoryId = v),
                range: _range,
                onRange: (v) => setState(() => _range = v),
                categories: availableCats,
                t: t,
                l: l,
              ).animate().fadeIn(duration: 500.ms, delay: 80.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 80.ms),
              const SizedBox(height: 16),

              // ── List or empty ────────────────────────────────────
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icon(isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 24),
                  title: t.tx.noResults,
                  description: _search.trim().isNotEmpty || _categoryId != 'all'
                      ? 'Try adjusting your filters.'
                      : '${t.tx.addFirst} ${widget.type.name}',
                  action: GradientButton(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    onPressed: () => AddTransactionSheet.show(context, initialType: widget.type),
                    child: Text(isExpense ? t.tx.addExpense : t.tx.addIncome),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 120.ms)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var gi = 0; gi < groups.entries.length; gi++)
                      fadeIn(
                        _TxGroup(
                          dateLabel: groups.entries.elementAt(gi).key,
                          items: groups.entries.elementAt(gi).value,
                          currency: currency,
                          state: s,
                          l: l,
                          onTap: (tx) => showTransactionDetail(context, tx),
                        ),
                        delay: Duration(milliseconds: gi * 50),
                      ),
                  ],
                ),
            ],
          ),
        ),
        // ── FAB ──────────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => AddTransactionSheet.show(context, initialType: widget.type),
            backgroundColor: AppColors.iris,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text(
              isExpense ? t.tx.addExpense : t.tx.addIncome,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header summary card
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final String title;
  final String rangeLabel;
  final double total;
  final int count;
  final String currency;
  final bool isExpense;
  final String addLabel;
  final VoidCallback onAdd;
  const _HeaderCard({
    required this.title,
    required this.rangeLabel,
    required this.total,
    required this.count,
    required this.currency,
    required this.isExpense,
    required this.addLabel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: l.surface3.withValues(alpha: 0.82),
        border: Border.all(color: l.border, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · $rangeLabel',
            style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(total, currency),
            style: AppTypography.amount(context, size: 32, weight: FontWeight.bold).copyWith(
              color: isExpense ? AppColors.error : AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count transaction${count != 1 ? 's' : ''}',
            style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              child: Text(addLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final String categoryId;
  final ValueChanged<String> onCategory;
  final String range;
  final ValueChanged<String> onRange;
  final List<Category> categories;
  final AppT t;
  final LuminaColors l;
  const _FilterBar({
    required this.search,
    required this.onSearch,
    required this.categoryId,
    required this.onCategory,
    required this.range,
    required this.onRange,
    required this.categories,
    required this.t,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (c, constraints) {
          final wide = constraints.maxWidth >= 640;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 3, child: _searchField(context)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _categoryDropdown(context)),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: _rangeDropdown(context)),
              ],
            );
          }
          return Column(
            children: [
              _searchField(context),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _categoryDropdown(context)),
                  const SizedBox(width: 8),
                  Expanded(child: _rangeDropdown(context)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
      ),
      child: TextFormField(
        initialValue: search,
        onChanged: onSearch,
        style: AppTypography.body(context, size: 13),
        decoration: InputDecoration(
          hintText: t.tx.searchPlaceholder,
          hintStyle: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: l.mutedForeground),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _categoryDropdown(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: categoryId,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: l.mutedForeground),
          style: AppTypography.body(context, size: 13),
          dropdownColor: l.surface2,
          items: [
            DropdownMenuItem(value: 'all', child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 14, color: l.mutedForeground),
                const SizedBox(width: 6),
                Expanded(child: Text(t.tx.allCategories, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),),
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: _hexColor(c.color), shape: BoxShape.circle),
                  ),
                  Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),),
          ],
          onChanged: (v) { if (v != null) onCategory(v); },
        ),
      ),
    );
  }

  Widget _rangeDropdown(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: range,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: l.mutedForeground),
          style: AppTypography.body(context, size: 13),
          dropdownColor: l.surface2,
          items: [
            DropdownMenuItem(value: '7', child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: l.mutedForeground),
                const SizedBox(width: 6),
                Expanded(child: Text(t.tx.last7, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),),
            DropdownMenuItem(value: '30', child: Text(t.tx.last30, maxLines: 1, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: '90', child: Text(t.tx.last90, maxLines: 1, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'all', child: Text(t.tx.allTime, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) { if (v != null) onRange(v); },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouped transaction list
// ─────────────────────────────────────────────────────────────────────────────
class _TxGroup extends StatelessWidget {
  final String dateLabel;
  final List<Transaction> items;
  final String currency;
  final FinTrackState state;
  final LuminaColors l;
  final void Function(Transaction) onTap;
  const _TxGroup({
    required this.dateLabel,
    required this.items,
    required this.currency,
    required this.state,
    required this.l,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final groupTotal = items.fold<double>(0, (a, t) => a + t.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateLabel, style: AppTypography.heading(context, size: 14)),
                Text(
                  '${items.length} · ${formatMoney(groupTotal, currency)}',
                  style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
                ),
              ],
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _TxItem(
                    tx: items[i],
                    currency: currency,
                    state: state,
                    l: l,
                    onTap: () => onTap(items[i]),
                  ),
                  if (i < items.length - 1) Divider(height: 1, color: l.border.withValues(alpha: 0.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final Transaction tx;
  final String currency;
  final FinTrackState state;
  final LuminaColors l;
  final VoidCallback onTap;
  const _TxItem({required this.tx, required this.currency, required this.state, required this.l, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = state.categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => state.categories.last,
    );
    final isIncome = tx.type == TxType.income;
    final color = _hexColor(cat.color);
    final title = tx.merchant ?? cat.name;
    final account = state.accounts.firstWhere(
      (a) => a.id == tx.account,
      orElse: () => state.accounts.isNotEmpty ? state.accounts.first : Account(id: '', name: tx.account, kind: '', balance: 0, color: '#6C5CE7'),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(cat.icon), size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body(context, size: 14, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(cat.name, style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground)),
                      const SizedBox(width: 6),
                      Container(
                        width: 3, height: 3,
                        decoration: BoxDecoration(color: l.mutedForeground.withValues(alpha: 0.5), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(account.name, style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (tx.recurring) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.repeat_rounded, size: 11, color: l.mutedForeground),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome ? '+' : '-'}${formatMoney(tx.amount, currency)}',
              style: AppTypography.amount(context, size: 14, weight: FontWeight.w600).copyWith(
                color: isIncome ? AppColors.success : l.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction detail dialog
// ─────────────────────────────────────────────────────────────────────────────
void showTransactionDetail(BuildContext context, Transaction tx) {
  showDialog<void>(
    context: context,
    builder: (_) => _TxDetailDialog(tx: tx),
  );
}

class _TxDetailDialog extends ConsumerWidget {
  final Transaction tx;
  const _TxDetailDialog({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final l = context.lumina;
    final currency = s.profile.baseCurrency;

    final cat = s.categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => s.categories.last,
    );
    final account = s.accounts.firstWhere(
      (a) => a.id == tx.account,
      orElse: () => Account(id: '', name: tx.account, kind: '', balance: 0, color: '#6C5CE7'),
    );
    final isIncome = tx.type == TxType.income;
    final color = _hexColor(cat.color);

    return Dialog(
      backgroundColor: l.surface.withValues(alpha: 0.98),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.tx.transactionDetails, style: AppTypography.heading(context, size: 16))),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: l.mutedForeground),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Hero
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_iconFor(cat.icon), size: 30, color: color),
                    ),
                    const SizedBox(height: 10),
                    Text(cat.name, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground)),
                    const SizedBox(height: 4),
                    Text(
                      '${isIncome ? '+' : '-'}${formatMoney(tx.amount, currency)}',
                      style: AppTypography.amount(context, size: 30, weight: FontWeight.bold).copyWith(
                        color: isIncome ? AppColors.success : l.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Meta rows
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: l.surface3.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
                ),
                child: Column(
                  children: [
                    _MetaRow(icon: Icons.storefront_outlined, label: t.common.merchant, value: tx.merchant ?? '—', l: l),
                    _MetaRow(icon: Icons.calendar_today_outlined, label: t.common.date, value: formatDate(tx.date, style: 'long'), l: l),
                    _MetaRow(icon: Icons.account_balance_outlined, label: t.common.account, value: account.name, l: l),
                    if (tx.note != null && tx.note!.isNotEmpty)
                      _MetaRow(icon: Icons.sticky_note_2_outlined, label: t.tx.note, value: tx.note!, l: l),
                    if (tx.recurring)
                      _MetaRow(icon: Icons.repeat_rounded, label: t.common.recurring, value: 'Yes', l: l),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        AddTransactionSheet.show(context, initialType: tx.type, editId: tx.id);
                      },
                      icon: Icon(Icons.edit_outlined, size: 16, color: l.foreground),
                      child: Text(t.common.edit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      onPressed: () {
                        ref.read(fintrackProvider.notifier).deleteTransaction(tx.id);
                        Navigator.of(context).maybePop();
                        showAppToast(context, t.messages.txDeleted, kind: ToastKind.success);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      child: Text(t.common.delete, style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LuminaColors l;
  const _MetaRow({required this.icon, required this.label, required this.value, required this.l});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: l.mutedForeground),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(context, size: 12, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return AppColors.iris;
}

IconData _iconFor(String name) {
  const m = <String, IconData>{
    'restaurant': Icons.restaurant_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'directions_car': Icons.directions_car_outlined,
    'shopping_bag': Icons.shopping_bag_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'home': Icons.home_outlined,
    'favorite': Icons.favorite_outline,
    'movie': Icons.movie_outlined,
    'school': Icons.school_outlined,
    'flight': Icons.flight_takeoff,
    'trending_up': Icons.trending_up_rounded,
    'wallet': Icons.account_balance_wallet_outlined,
    'laptop': Icons.laptop_mac_outlined,
    'card_giftcard': Icons.card_giftcard,
    'more_horiz': Icons.more_horiz,
  };
  return m[name] ?? Icons.category_outlined;
}
