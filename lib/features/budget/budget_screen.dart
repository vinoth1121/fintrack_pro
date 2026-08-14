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

/// Budget center — mirrors the web app's `views/budget.tsx`.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final derived = ref.watch(derivedProvider);
    final currency = state.profile.baseCurrency;

    final usage = derived.budgetUsage;
    final totalLimit = usage.fold(0.0, (a, b) => a + b.limit);
    final totalSpent = usage.fold(0.0, (a, b) => a + b.spent);
    final overallPct = pct(totalSpent, totalLimit);
    final overallColor = overallPct >= 100
        ? AppColors.error
        : overallPct >= 80
            ? AppColors.warning
            : AppColors.success;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _Hero(
                  pill: t.budget.budgetCenter,
                  pillIcon: Icons.savings_outlined,
                  caption: t.budget.totalBudgeted,
                  totalSpent: totalSpent,
                  totalLimit: totalLimit,
                  currency: currency,
                  pctValue: overallPct,
                  used: t.budget.used,
                  remaining: t.budget.remaining,
                  ringColor: overallColor,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SectionHeader(
                  title: t.budget.yourBudgets,
                  subtitle: '${usage.length} ${t.common.active}',
                  action: GradientButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showCreateDialog(context),
                    child: Text(t.budget.newBudget),
                  ),
                ),
              ),
            ),
            if (usage.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: const Icon(Icons.savings_outlined),
                      title: t.budget.noBudgets,
                      description:
                          'Create category budgets to track spending limits and get alerts.',
                      action: GradientButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showCreateDialog(context),
                        child: Text(t.budget.createBudget),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BudgetCard(
                      usage: usage[i],
                      currency: currency,
                      onTrackLabel: t.common.onTrack,
                      approachingLabel: t.budget.approachingLimit,
                      overLabel: t.budget.overBudget,
                      ofLabel: t.common.of,
                      leftLabel: t.common.left,
                      onDelete: () {
                        ref.read(fintrackProvider.notifier).deleteBudget(usage[i].budgetId);
                        showAppToast(context, 'Budget deleted', kind: ToastKind.success);
                      },
                    ).animate().fadeIn(
                      duration: 400.ms,
                      delay: (i * 60).ms,
                    ).slideY(begin: 0.05),
                    childCount: usage.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateBudgetDialog(),
    );
  }
}

class _Hero extends StatelessWidget {
  final String pill, caption, used, remaining;
  final IconData pillIcon;
  final double totalSpent, totalLimit;
  final String currency;
  final int pctValue;
  final Color ringColor;
  const _Hero({
    required this.pill,
    required this.pillIcon,
    required this.caption,
    required this.totalSpent,
    required this.totalLimit,
    required this.currency,
    required this.pctValue,
    required this.used,
    required this.remaining,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Aurora-style backdrop
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.iris.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pillIcon, size: 12),
                          const SizedBox(width: 4),
                          Text(pill),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(caption,
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: formatMoney(totalSpent, currency),
                            style: AppTypography.amount(context,
                                    size: 30, weight: FontWeight.bold,)
                                .copyWith(letterSpacing: -0.5),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: '/ ${formatMoney(totalLimit, currency)}',
                            style: AppTypography.amount(context,
                                    size: 16, weight: FontWeight.w500,)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pctValue% $used · ${formatMoney((totalLimit - totalSpent).clamp(0, double.infinity), currency)} $remaining',
                      style: AppTypography.body(context, size: 12, weight: FontWeight.w600)
                          .copyWith(color: ringColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: pctValue.toDouble(),
                size: 110,
                stroke: 10,
                color: ringColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pctValue%',
                        style: AppTypography.amount(context,
                                size: 22, weight: FontWeight.bold,)
                            .copyWith(height: 1.0),),
                    Text(used.toUpperCase(),
                        style: AppTypography.label(context, size: 9)
                            .copyWith(color: l.mutedForeground, letterSpacing: 1.2),),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetUsage usage;
  final String currency;
  final String onTrackLabel, approachingLabel, overLabel;
  final String ofLabel, leftLabel;
  final VoidCallback onDelete;
  const _BudgetCard({
    required this.usage,
    required this.currency,
    required this.onTrackLabel,
    required this.approachingLabel,
    required this.overLabel,
    required this.ofLabel,
    required this.leftLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final color = usage.over
        ? AppColors.error
        : usage.pct >= 80
            ? AppColors.warning
            : AppColors.success;
    final status = usage.over
        ? overLabel
        : usage.pct >= 80
            ? approachingLabel
            : onTrackLabel;
    final catColor = _hexColor(usage.color);

    return GlassCard(
      hover: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(usage.icon), color: catColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usage.categoryName,
                        style: AppTypography.heading(context, size: 15),),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          usage.over ? Icons.warning_amber_rounded : Icons.check_circle,
                          size: 12,
                          color: usage.over ? AppColors.error : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(status,
                            style: AppTypography.body(context, size: 11)
                                .copyWith(color: l.mutedForeground),),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: l.mutedForeground,
                splashRadius: 18,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(usage.spent, currency),
                      style: AppTypography.amount(context, size: 22, weight: FontWeight.bold)
                          .copyWith(color: color),
                    ),
                    Text(
                      '$ofLabel ${formatMoney(usage.limit, currency)}',
                      style: AppTypography.body(context, size: 11)
                          .copyWith(color: l.mutedForeground),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${usage.pct}%',
                      style: AppTypography.amount(context, size: 16, weight: FontWeight.w600),),
                  Text(
                    usage.over
                        ? '${formatMoney(usage.spent - usage.limit, currency)} over'
                        : '${formatMoney(usage.remaining, currency)} $leftLabel',
                    style: AppTypography.body(context, size: 11)
                        .copyWith(color: l.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (usage.pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: l.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ).animate().fadeIn(duration: 700.ms).slideX(begin: -0.05),
        ],
      ),
    );
  }
}

class _CreateBudgetDialog extends ConsumerStatefulWidget {
  const _CreateBudgetDialog();

  @override
  ConsumerState<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends ConsumerState<_CreateBudgetDialog> {
  late String _categoryId;
  final _limitCtrl = TextEditingController(text: '5000');
  BudgetPeriod _period = BudgetPeriod.monthly;
  bool _rollover = false;

  @override
  void initState() {
    super.initState();
    final cats = ref.read(fintrackProvider).categories;
    final expense = cats
        .where((c) => c.kind == CategoryKind.expense || c.kind == CategoryKind.both)
        .toList();
    _categoryId = expense.isNotEmpty ? expense.first.id : (cats.isNotEmpty ? cats.first.id : '');
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final limit = double.tryParse(_limitCtrl.text) ?? 0;
    if (_categoryId.isEmpty || limit <= 0) {
      showAppToast(context, 'Pick a category and enter a valid limit',
          kind: ToastKind.error,);
      return;
    }
    ref.read(fintrackProvider.notifier).addBudget(Budget(
      id: uid('b_'),
      categoryId: _categoryId,
      limit: limit,
      period: _period,
      rollover: _rollover,
      createdAt: DateTime.now(),
    ),);
    showAppToast(context, 'Budget created', kind: ToastKind.success);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final cats = ref.watch(fintrackProvider).categories;
    final expense = cats
        .where((c) => c.kind == CategoryKind.expense || c.kind == CategoryKind.both)
        .toList();

    final periodOptions = <(BudgetPeriod, String)>[
      (BudgetPeriod.weekly, t.budget.weekly),
      (BudgetPeriod.monthly, t.budget.monthly),
      (BudgetPeriod.yearly, t.budget.yearly),
    ];

    return Dialog(
      backgroundColor: l.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(t.budget.createBudget,
                          style: AppTypography.heading(context, size: 18),),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, size: 18),
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Label(text: t.common.category),
                const SizedBox(height: 6),
                _DropdownField(
                  value: _categoryId,
                  items: expense.isEmpty
                      ? [(cats.first.id, cats.first.name)]
                      : expense.map((c) => (c.id, c.name)).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 14),
                _Label(text: t.budget.limitAmount),
                const SizedBox(height: 6),
                TextField(
                  controller: _limitCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTypography.amount(context, size: 18),
                  decoration: _inputDecoration(l),
                ),
                const SizedBox(height: 14),
                _Label(text: t.budget.period),
                const SizedBox(height: 6),
                Row(
                  children: periodOptions
                      .map((o) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: o == periodOptions.last ? 0 : 8,),
                              child: _SegmentButton(
                                label: o.$2,
                                selected: _period == o.$1,
                                onTap: () => setState(() => _period = o.$1),
                              ),
                            ),
                          ),)
                      .toList(),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _rollover = !_rollover),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: l.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.refresh, size: 16, color: AppColors.iris),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.budget.rolloverUnused,
                              style: AppTypography.body(context, size: 13),),
                        ),
                        Switch(
                          value: _rollover,
                          activeThumbColor: AppColors.iris,
                          onChanged: (v) => setState(() => _rollover = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  onPressed: _save,
                  expanded: true,
                  child: Text(t.budget.createBudget),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(LuminaColors l) => InputDecoration(
        filled: true,
        fillColor: l.surface3.withValues(alpha: 0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: l.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: l.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.iris, width: 1.2),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Text(text.toUpperCase(),
        style: AppTypography.label(context, size: 10)
            .copyWith(color: l.mutedForeground, letterSpacing: 1.2),);
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  const _DropdownField(
      {required this.value, required this.items, required this.onChanged,});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: l.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: l.surface2,
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e.$1,
                    child: Text(e.$2, style: AppTypography.body(context, size: 14)),
                  ),)
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton(
      {required this.label, required this.selected, required this.onTap,});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.iris.withValues(alpha: 0.12)
                : l.surface3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.iris : l.border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                  .copyWith(color: selected ? AppColors.iris : l.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- helpers ---------------------------------------------------------------

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return AppColors.iris;
}

IconData _iconFor(String name) {
  const m = <String, IconData>{
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart_outlined,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag_outlined,
    'receipt_long': Icons.receipt_long,
    'home': Icons.home,
    'favorite': Icons.favorite,
    'movie': Icons.movie,
    'school': Icons.school,
    'flight': Icons.flight,
    'trending_up': Icons.trending_up,
    'wallet': Icons.account_balance_wallet,
    'laptop': Icons.laptop,
    'card_giftcard': Icons.card_giftcard,
    'more_horiz': Icons.more_horiz,
    'verified_user': Icons.verified_user,
    'music_note': Icons.music_note,
    'cloud': Icons.cloud,
    'description': Icons.description,
    'palette': Icons.palette,
    'inventory_2': Icons.inventory_2_outlined,
    'target': Icons.gps_fixed,
    'gift': Icons.card_giftcard,
    'smartphone': Icons.smartphone,
  };
  return m[name] ?? Icons.category;
}
