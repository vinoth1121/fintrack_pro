import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart' show GradientButton;
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// Add / edit transaction bottom sheet.
/// Mirrors the web `add-transaction-sheet.tsx`: type toggle, amount numpad,
/// category grid, merchant / date / account / note fields, recurring switch,
/// and a smart budget alert that pushes a notification when an expense crosses
/// 90% or 100% of its category budget.
class AddTransactionSheet extends ConsumerStatefulWidget {
  final TxType initialType;
  final String? editId;

  const AddTransactionSheet({
    super.key,
    required this.initialType,
    this.editId,
  });

  /// Convenience launcher used by the transactions screen FAB.
  static Future<void> show(
    BuildContext context, {
    required TxType initialType,
    String? editId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: AddTransactionSheet(initialType: initialType, editId: editId),
      ),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late TxType _type;
  late String _amount;
  late String _categoryId;
  late String _accountId;
  late DateTime _date;
  late TextEditingController _merchantCtrl;
  late TextEditingController _noteCtrl;
  late bool _recurring;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final s = ref.read(fintrackProvider);
    Transaction? editing;
    if (widget.editId != null) {
      for (final tx in s.transactions) {
        if (tx.id == widget.editId) {
          editing = tx;
          break;
        }
      }
    }
    final cats = s.categories;
    final accs = s.accounts;
    final availableCats = cats.where((c) => _catMatches(c, _type)).toList();
    _amount = editing != null ? _stripTrailing(editing.amount) : '0';
    _categoryId = editing?.categoryId ?? (availableCats.isNotEmpty ? availableCats.first.id : '');
    _accountId = editing?.account ?? (accs.isNotEmpty ? accs.first.id : '');
    _date = editing?.date ?? DateTime.now();
    _merchantCtrl = TextEditingController(text: editing?.merchant ?? '');
    _noteCtrl = TextEditingController(text: editing?.note ?? '');
    _recurring = editing?.recurring ?? false;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _catMatches(Category c, TxType type) {
    return type == TxType.income
        ? c.kind == CategoryKind.income || c.kind == CategoryKind.both
        : c.kind == CategoryKind.expense || c.kind == CategoryKind.both;
  }

  String _stripTrailing(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  double get _numericAmount => double.tryParse(_amount) ?? 0;

  void _press(String key) {
    setState(() {
      if (_amount == '0' && key != '.') {
        _amount = key;
      } else if (key == '.' && _amount.contains('.')) {
        return;
      } else if (key == '.' && _amount.isEmpty) {
        _amount = '0.';
      } else {
        if (_amount.length >= 12) return;
        _amount = _amount + key;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final t = ref.read(tProvider);
    final s = ref.read(fintrackProvider);
    final notifier = ref.read(fintrackProvider.notifier);
    final currency = s.profile.baseCurrency;

    if (_numericAmount <= 0) {
      showAppToast(context, t.messages.enterAmount, kind: ToastKind.error);
      return;
    }
    if (_categoryId.isEmpty) {
      showAppToast(context, t.messages.pickCategory, kind: ToastKind.error);
      return;
    }

    final tx = Transaction(
      id: widget.editId ?? uid('t-'),
      type: _type,
      amount: _numericAmount,
      categoryId: _categoryId,
      account: _accountId,
      date: DateTime(_date.year, _date.month, _date.day),
      merchant: _merchantCtrl.text.trim().isEmpty ? null : _merchantCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      recurring: _recurring,
      createdAt: DateTime.now(),
    );

    if (widget.editId != null) {
      notifier.updateTransaction(widget.editId!, tx);
      showAppToast(context, t.messages.txUpdated);
    } else {
      notifier.addTransaction(tx);
      final msg = _type == TxType.expense
          ? 'Expense of ${formatMoney(_numericAmount, currency)} logged'
          : 'Income of ${formatMoney(_numericAmount, currency)} added';
      showAppToast(context, msg);

      // Smart budget alert (expense only)
      if (_type == TxType.expense) {
        _maybePushBudgetAlert(s, currency);
      }
    }
    Navigator.of(context).maybePop();
  }

  void _maybePushBudgetAlert(FinTrackState s, String currency) {
    final budget = s.budgets.firstWhere(
      (b) => b.categoryId == _categoryId,
      orElse: () => Budget(
        id: '_none_',
        categoryId: '',
        limit: 0,
        period: BudgetPeriod.monthly,
        rollover: false,
        createdAt: DateTime.now(),
      ),
    );
    if (budget.id == '_none_' || budget.limit <= 0) return;

    final now = DateTime.now();
    final spent = s.transactions
        .where((t) =>
            t.type == TxType.expense &&
            t.categoryId == _categoryId &&
            t.date.year == now.year &&
            t.date.month == now.month,)
        .fold<double>(0.0, (a, t) => a + t.amount) + _numericAmount;
    final p = (spent / budget.limit) * 100;
    final catName = s.categories.firstWhere(
      (c) => c.id == _categoryId,
      orElse: () => s.categories.last,
    ).name;

    if (p >= 100) {
      ref.read(fintrackProvider.notifier).pushNotification(AppNotification(
        id: uid('n-'),
        title: 'Budget exceeded',
        body: "You've gone over your $catName budget by ${formatMoney(spent - budget.limit, currency)}.",
        kind: NotificationKind.error,
        read: false,
        createdAt: DateTime.now(),
        action: const NotificationAction(label: 'Review', view: 'budget'),
      ),);
    } else if (p >= 90) {
      ref.read(fintrackProvider.notifier).pushNotification(AppNotification(
        id: uid('n-'),
        title: 'Budget alert',
        body: "You've used ${p.round()}% of your $catName budget.",
        kind: NotificationKind.warning,
        read: false,
        createdAt: DateTime.now(),
        action: const NotificationAction(label: 'Review', view: 'budget'),
      ),);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final l = context.lumina;
    final currency = s.profile.baseCurrency;
    final availableCats = s.categories.where((c) => _catMatches(c, _type)).toList();
    final isExpense = _type == TxType.expense;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: l.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: l.surface3, borderRadius: BorderRadius.circular(999)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Text(
                  widget.editId != null
                      ? t.tx.editTransaction
                      : (isExpense ? t.tx.addExpense : t.tx.addIncome),
                  style: AppTypography.heading(context, size: 17),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: l.mutedForeground, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Type toggle ────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TypeToggle(
                            active: isExpense,
                            color: AppColors.error,
                            icon: Icons.arrow_downward_rounded,
                            label: t.common.expense,
                            onTap: () => setState(() => _type = TxType.expense),
                          ),
                        ),
                        Expanded(
                          child: _TypeToggle(
                            active: !isExpense,
                            color: AppColors.success,
                            icon: Icons.arrow_upward_rounded,
                            label: t.common.income,
                            onTap: () => setState(() => _type = TxType.income),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Amount display ─────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          t.common.amount.toUpperCase(),
                          style: AppTypography.label(context, size: 10).copyWith(
                            letterSpacing: 1.4,
                            color: l.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(_numericAmount, currency),
                          style: AppTypography.amount(context, size: 36, weight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // ── Numpad ─────────────────────────────────────────
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      _numKey('1'), _numKey('2'), _numKey('3'),
                      _numKey('4'), _numKey('5'), _numKey('6'),
                      _numKey('7'), _numKey('8'), _numKey('9'),
                      _numKey('.'), _numKey('0'),
                      _numKey('back', icon: Icons.backspace_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Category picker ────────────────────────────────
                  _Label(text: t.common.category),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.85,
                    children: [
                      for (final c in availableCats)
                        _CategoryCell(
                          category: c,
                          active: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Fields ─────────────────────────────────────────
                  _Field(
                    label: t.tx.merchantSource,
                    icon: Icons.storefront_outlined,
                    child: TextField(
                      controller: _merchantCtrl,
                      style: AppTypography.body(context, size: 14),
                      decoration: _inputDecoration(l, isExpense ? 'e.g. Swiggy' : 'e.g. Acme Corp'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: t.common.date,
                    icon: Icons.calendar_today_outlined,
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(text: formatDate(_date, style: 'long')),
                          style: AppTypography.body(context, size: 14),
                          decoration: _inputDecoration(l, '').copyWith(
                            suffixIcon: const Icon(Icons.event_outlined, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _Label(text: t.common.account),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in s.accounts)
                        _AccountChip(
                          account: a,
                          active: _accountId == a.id,
                          onTap: () => setState(() => _accountId = a.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _Field(
                    label: t.tx.note,
                    icon: Icons.sticky_note_2_outlined,
                    child: TextField(
                      controller: _noteCtrl,
                      style: AppTypography.body(context, size: 14),
                      maxLines: 2,
                      decoration: _inputDecoration(l, 'Add a note (optional)'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Recurring switch ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: l.border.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.tx.recurringTx, style: AppTypography.body(context, size: 13)),
                        Switch(
                          value: _recurring,
                          activeThumbColor: AppColors.iris,
                          onChanged: (v) => setState(() => _recurring = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // ── Save ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      child: Text(
                        widget.editId != null
                            ? t.common.saveChanges
                            : (isExpense ? t.tx.addExpense : t.tx.addIncome),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(LuminaColors l, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground),
      filled: true,
      fillColor: l.surface3.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: l.border.withValues(alpha: 0.5), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: l.border.withValues(alpha: 0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
      ),
    );
  }

  Widget _numKey(String k, {IconData? icon}) {
    final l = context.lumina;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => k == 'back' ? _backspace() : _press(k),
        child: Container(
          decoration: BoxDecoration(
            color: l.surface2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: l.border.withValues(alpha: 0.4), width: 1),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 22, color: l.foreground)
              : Text(
                  k,
                  style: AppTypography.amount(context, size: 20, weight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _TypeToggle extends StatelessWidget {
  final bool active;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TypeToggle({required this.active, required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: color.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? color : context.lumina.mutedForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.body(context, size: 13, weight: FontWeight.w600).copyWith(
                  color: active ? color : context.lumina.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Text(
      text.toUpperCase(),
      style: AppTypography.label(context, size: 10).copyWith(
        letterSpacing: 1.4,
        color: l.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget child;
  const _Field({required this.label, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: l.mutedForeground),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: AppTypography.label(context, size: 10).copyWith(
                letterSpacing: 1.4,
                color: l.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _CategoryCell extends StatelessWidget {
  final Category category;
  final bool active;
  final VoidCallback onTap;
  const _CategoryCell({required this.category, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(category.color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : context.lumina.surface3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: color, width: 2)
                : Border.all(color: context.lumina.border.withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFor(category.icon), size: 16, color: color),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(context, size: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final Account account;
  final bool active;
  final VoidCallback onTap;
  const _AccountChip({required this.account, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(account.color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : context.lumina.surface3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: color, width: 2)
                : Border.all(color: context.lumina.border.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(account.name, style: AppTypography.body(context, size: 12, weight: FontWeight.w500)),
            ],
          ),
        ),
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
