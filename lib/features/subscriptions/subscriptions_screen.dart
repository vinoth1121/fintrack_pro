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

/// Subscriptions — mirrors the web app's `views/subscriptions.tsx`.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final currency = state.profile.baseCurrency;
    final subs = state.subscriptions;
    final active = subs.where((s) => s.active).toList();
    final monthlyTotal = active.fold(0.0, (sum, s) {
      if (s.cycle == 'monthly') return sum + s.amount;
      if (s.cycle == 'yearly') return sum + s.amount / 12;
      return sum + s.amount * 4.33;
    });
    final yearlyTotal = monthlyTotal * 12;
    active.sort((a, b) => a.nextBilling.compareTo(b.nextBilling));
    final next = active.isNotEmpty ? active.first : null;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _Hero(
                  pill: t.subscriptions.subscriptionTracker,
                  monthlyCost: t.subscriptions.monthlyCost,
                  monthlyTotal: monthlyTotal,
                  yearlyTotal: yearlyTotal,
                  currency: currency,
                  perYearLabel: t.subscriptions.perYear,
                  activeCount: active.length,
                  cancelledCount: subs.length - active.length,
                  activeLabel: t.subscriptions.active,
                  cancelledLabel: t.subscriptions.cancelled,
                  addLabel: t.subscriptions.addSubscription,
                  onAdd: () => _showAdd(context),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            if (next != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _NextRenewalRow(
                    t: t,
                    currency: currency,
                    next: next,
                    monthlyTotal: monthlyTotal,
                  ).animate().fadeIn(delay: 80.ms, duration: 400.ms).slideY(begin: 0.05),
                ),
              ),
            if (subs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: const Icon(Icons.repeat),
                      title: t.subscriptions.noSubscriptions,
                      description: t.misc.neverMissRenewal,
                      action: GradientButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAdd(context),
                        child: Text(t.subscriptions.addSubscription),
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
                    childAspectRatio: 1.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _SubCard(
                      sub: subs[i],
                      currency: currency,
                      perMonthLabel: t.subscriptions.perMonth,
                      perYearLabel: t.subscriptions.perYear,
                      perWeekLabel: t.common.week,
                      daysLeftLabel: t.subscriptions.daysLeft,
                      renewsTodayLabel: t.subscriptions.renewsToday,
                      pausedLabel: t.subscriptions.paused,
                      leftLabel: t.common.left,
                      onToggle: () {
                        ref
                            .read(fintrackProvider.notifier)
                            .updateSubscription(subs[i].id, subs[i].copyWith(active: !subs[i].active));
                        showAppToast(
                          context,
                          subs[i].active ? 'Subscription paused' : 'Subscription resumed',
                          kind: ToastKind.success,
                        );
                      },
                      onDelete: () {
                        ref
                            .read(fintrackProvider.notifier)
                            .deleteSubscription(subs[i].id);
                        showAppToast(context, t.messages.subRemoved,
                            kind: ToastKind.success,);
                      },
                    ).animate().fadeIn(
                      duration: 400.ms,
                      delay: (i * 50).ms,
                    ).slideY(begin: 0.05),
                    childCount: subs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAdd(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _AddSubDialog(),
    );
  }
}

class _Hero extends StatelessWidget {
  final String pill, monthlyCost;
  final double monthlyTotal, yearlyTotal;
  final String currency;
  final String perYearLabel;
  final int activeCount, cancelledCount;
  final String activeLabel, cancelledLabel;
  final String addLabel;
  final VoidCallback onAdd;
  const _Hero({
    required this.pill,
    required this.monthlyCost,
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.currency,
    required this.perYearLabel,
    required this.activeCount,
    required this.cancelledCount,
    required this.activeLabel,
    required this.cancelledLabel,
    required this.addLabel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      strong: true,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withValues(alpha: 0.25),
                  Colors.transparent,
                ],),
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
                          const Icon(Icons.repeat, size: 12),
                          const SizedBox(width: 4),
                          Text(pill),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(monthlyCost,
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: formatMoney(monthlyTotal, currency),
                            style: AppTypography.amount(context,
                                    size: 30, weight: FontWeight.bold,)
                                .copyWith(letterSpacing: -0.5),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: '/mo',
                            style: AppTypography.amount(context,
                                    size: 16, weight: FontWeight.w500,)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),
                        children: [
                          const TextSpan(text: "That's "),
                          TextSpan(
                            text: formatMoney(yearlyTotal, currency),
                            style: AppTypography.body(context,
                                    size: 12, weight: FontWeight.w700,)
                                .copyWith(color: AppColors.iris),
                          ),
                          TextSpan(text: ' $perYearLabel'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _MiniStat(
                        value: '$activeCount',
                        label: activeLabel,
                      ),
                      const SizedBox(width: 8),
                      _MiniStat(
                        value: '$cancelledCount',
                        label: cancelledLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GradientButton(
                    icon: const Icon(Icons.add, size: 14),
                    onPressed: onAdd,
                    child: Text(addLabel),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: l.surface3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTypography.amount(context, size: 18, weight: FontWeight.bold),),
          Text(label,
              style: AppTypography.label(context, size: 9)
                  .copyWith(color: l.mutedForeground, letterSpacing: 0.8),),
        ],
      ),
    );
  }
}

class _NextRenewalRow extends StatelessWidget {
  final AppT t;
  final String currency;
  final Subscription next;
  final double monthlyTotal;
  const _NextRenewalRow({
    required this.t,
    required this.currency,
    required this.next,
    required this.monthlyTotal,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final color = _hexColor(next.color);
    final daysLeft =
        next.nextBilling.difference(DateTime.now()).inDays.clamp(0, 99999);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final renewalCard = GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(next.icon), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.subscriptions.nextRenewal,
                        style: AppTypography.label(context, size: 10)
                            .copyWith(color: l.mutedForeground, letterSpacing: 1),),
                    const SizedBox(height: 2),
                    Text(next.name,
                        style: AppTypography.heading(context, size: 14),),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 11, color: AppColors.iris),
                        const SizedBox(width: 4),
                        Text(formatDate(next.nextBilling, style: 'long'),
                            style: AppTypography.body(context, size: 11)
                                .copyWith(color: l.mutedForeground),),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(next.amount, currency),
                      style: AppTypography.amount(context,
                              size: 18, weight: FontWeight.bold,)
                          .copyWith(height: 1.0),),
                  Text('$daysLeft ${t.subscriptions.daysLeft}',
                      style: AppTypography.body(context, size: 11)
                          .copyWith(color: l.mutedForeground),),
                ],
              ),
            ],
          ),
        );
        final tipCard = GlassCard(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.iris.withValues(alpha: 0.12),
                  AppColors.cyan.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.iris, size: 18,),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.body(context, size: 11).copyWith(height: 1.4),
                      children: [
                        TextSpan(
                          text: '${t.subscriptions.aiTip}: ',
                          style: AppTypography.body(context,
                                  size: 11, weight: FontWeight.w700,)
                              .copyWith(color: AppColors.iris),
                        ),
                        TextSpan(
                          text:
                              "Cancelling unused streaming services could save you ~${formatMoney(monthlyTotal * 0.2, currency)}/mo.",
                          style: AppTypography.body(context, size: 11)
                              .copyWith(color: l.foreground.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return wide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: renewalCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: tipCard),
                  ],
                ),
              )
            : Column(
                children: [
                  renewalCard,
                  const SizedBox(height: 12),
                  tipCard,
                ],
              );
      },
    );
  }
}

class _SubCard extends StatelessWidget {
  final Subscription sub;
  final String currency;
  final String perMonthLabel, perYearLabel, perWeekLabel;
  final String daysLeftLabel, renewsTodayLabel, pausedLabel, leftLabel;
  final VoidCallback onToggle, onDelete;

  const _SubCard({
    required this.sub,
    required this.currency,
    required this.perMonthLabel,
    required this.perYearLabel,
    required this.perWeekLabel,
    required this.daysLeftLabel,
    required this.renewsTodayLabel,
    required this.pausedLabel,
    required this.leftLabel,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final color = _hexColor(sub.color);
    final daysLeft =
        sub.nextBilling.difference(DateTime.now()).inDays.clamp(0, 99999);
    final dueSoon = sub.active && daysLeft <= 7;
    final cycleLabel = sub.cycle == 'monthly'
        ? perMonthLabel
        : sub.cycle == 'yearly'
            ? perYearLabel
            : 'per $perWeekLabel';

    return GlassCard(
      hover: true,
      padding: const EdgeInsets.all(14),
      child: Opacity(
        opacity: sub.active ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(sub.icon), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name,
                          style: AppTypography.heading(context, size: 14),),
                      const SizedBox(height: 2),
                      Text(sub.category,
                          style: AppTypography.body(context, size: 11)
                              .copyWith(color: l.mutedForeground),),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  color: sub.active ? AppColors.success : l.mutedForeground,
                  splashRadius: 18,
                  tooltip: sub.active ? 'Pause' : 'Resume',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatMoney(sub.amount, currency),
                          style: AppTypography.amount(context,
                                  size: 20, weight: FontWeight.bold,)
                              .copyWith(height: 1.0),),
                      Text(cycleLabel,
                          style: AppTypography.body(context, size: 11)
                              .copyWith(color: l.mutedForeground),),
                    ],
                  ),
                ),
                if (sub.active)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dueSoon
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: dueSoon
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : l.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dueSoon)
                          const Icon(Icons.error_outline,
                              size: 11, color: AppColors.warning,),
                        if (dueSoon) const SizedBox(width: 4),
                        Text(
                          daysLeft == 0
                              ? renewsTodayLabel
                              : '${daysLeft}d $leftLabel',
                          style: AppTypography.body(context, size: 11, weight: FontWeight.w600)
                              .copyWith(
                                  color: dueSoon
                                      ? AppColors.warning
                                      : l.foreground,),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: l.border, width: 1),
                    ),
                    child: Text(pausedLabel,
                        style: AppTypography.body(context, size: 11, weight: FontWeight.w600)
                            .copyWith(color: l.mutedForeground),),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSubDialog extends ConsumerStatefulWidget {
  const _AddSubDialog();

  @override
  ConsumerState<_AddSubDialog> createState() => _AddSubDialogState();
}

class _AddSubDialogState extends ConsumerState<_AddSubDialog> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '499');
  String _cycle = 'monthly';
  String _category = 'Entertainment';
  String _icon = _kSubIcons.first.$1;
  String _color = _kSubColors.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final t = ref.read(tProvider);
    final a = double.tryParse(_amountCtrl.text) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || a <= 0) {
      showAppToast(context, t.messages.enterNameAmount, kind: ToastKind.error);
      return;
    }
    final offset = _cycle == 'monthly'
        ? 30
        : _cycle == 'yearly'
            ? 365
            : 7;
    final nextBilling = DateTime.now().add(Duration(days: offset));
    ref.read(fintrackProvider.notifier).addSubscription(Subscription(
          id: uid('s_'),
          name: _nameCtrl.text.trim(),
          amount: a,
          cycle: _cycle,
          nextBilling: nextBilling,
          category: _category,
          icon: _icon,
          color: _color,
          active: true,
        ),);
    showAppToast(context, t.messages.subAdded, kind: ToastKind.success);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final cycles = <(String, String)>[
      ('weekly', t.budget.weekly),
      ('monthly', t.budget.monthly),
      ('yearly', t.budget.yearly),
    ];
    final categories = <String>[
      'Entertainment', 'Productivity', 'Cloud', 'Software',
      'Shopping', 'News', 'Music',
    ];

    return Dialog(
      backgroundColor: l.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                      child: Text(t.subscriptions.addSubscriptionTitle,
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
                const SizedBox(height: 14),
                _Label(text: t.subscriptions.name),
                const SizedBox(height: 6),
                _TextField(
                  controller: _nameCtrl,
                  hint: 'e.g. Netflix',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(text: t.common.amount),
                          const SizedBox(height: 6),
                          _TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            amountStyle: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label(text: 'Cycle'),
                          const SizedBox(height: 6),
                          _DropdownField(
                            value: _cycle,
                            items: cycles,
                            onChanged: (v) => setState(() => _cycle = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Label(text: t.common.category),
                const SizedBox(height: 6),
                _DropdownField(
                  value: _category,
                  items: categories.map((c) => (c, c)).toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 12),
                _Label(text: t.goals.icon),
                const SizedBox(height: 6),
                _IconPicker(
                  selected: _icon,
                  items: _kSubIcons,
                  onPicked: (v) => setState(() => _icon = v),
                ),
                const SizedBox(height: 12),
                _Label(text: t.goals.color),
                const SizedBox(height: 6),
                _ColorPicker(
                  selected: _color,
                  onPicked: (v) => setState(() => _color = v),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  onPressed: _save,
                  expanded: true,
                  child: Text(t.subscriptions.addSubscription),
                ),
              ],
            ),
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
    return Text(text.toUpperCase(),
        style: AppTypography.label(context, size: 10)
            .copyWith(color: l.mutedForeground, letterSpacing: 1.2),);
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool amountStyle;
  const _TextField({
    required this.controller,
    this.hint,
    this.keyboardType,
    this.amountStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: amountStyle
          ? AppTypography.amount(context, size: 18)
          : AppTypography.body(context, size: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body(context, size: 14)
            .copyWith(color: l.mutedForeground),
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
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

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
                    child: Text(e.$2,
                        style: AppTypography.body(context, size: 14),),
                  ),)
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final List<(String, IconData)> items;
  final ValueChanged<String> onPicked;
  const _IconPicker({
    required this.selected,
    required this.items,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        final isSel = e.$1 == selected;
        return InkWell(
          onTap: () => onPicked(e.$1),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.iris.withValues(alpha: 0.12)
                  : l.surface3.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? AppColors.iris : l.border,
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Icon(e.$2,
                size: 16,
                color: isSel ? AppColors.iris : l.foreground,),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPicked;
  const _ColorPicker({required this.selected, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _kSubColors.map((hex) {
        final color = _hexColor(hex);
        final isSel = hex == selected;
        return InkWell(
          onTap: () => onPicked(hex),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSel ? Border.all(color: color, width: 3) : null,
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSel
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ---- helpers ---------------------------------------------------------------

const _kSubIcons = <(String, IconData)>[
  ('movie', Icons.movie),
  ('music_note', Icons.music_note),
  ('cloud', Icons.cloud),
  ('description', Icons.description),
  ('palette', Icons.palette),
  ('inventory_2', Icons.inventory_2_outlined),
  ('gamepad', Icons.gamepad_outlined),
  ('newspaper', Icons.newspaper),
  ('live_tv', Icons.live_tv),
  ('smartphone', Icons.smartphone),
];

const _kSubColors = <String>[
  '#6C5CE7', '#00D2FF', '#00E676', '#FFB74D',
  '#FF5252', '#448AFF', '#FF6FB5', '#B388FF',
];

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return AppColors.iris;
}

IconData _iconFor(String name) {
  const m = <String, IconData>{
    'movie': Icons.movie,
    'music_note': Icons.music_note,
    'cloud': Icons.cloud,
    'description': Icons.description,
    'palette': Icons.palette,
    'inventory_2': Icons.inventory_2_outlined,
    'gamepad': Icons.gamepad_outlined,
    'newspaper': Icons.newspaper,
    'live_tv': Icons.live_tv,
    'smartphone': Icons.smartphone,
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart_outlined,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag_outlined,
    'receipt_long': Icons.receipt_long,
    'home': Icons.home,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'flight': Icons.flight,
    'trending_up': Icons.trending_up,
    'wallet': Icons.account_balance_wallet,
    'laptop': Icons.laptop,
    'card_giftcard': Icons.card_giftcard,
    'more_horiz': Icons.more_horiz,
    'verified_user': Icons.verified_user,
    'target': Icons.gps_fixed,
    'gift': Icons.card_giftcard,
    'clapperboard': Icons.movie,
    'tv': Icons.live_tv,
    'package': Icons.inventory_2_outlined,
    'file_text': Icons.description,
  };
  return m[name] ?? Icons.subscriptions_outlined;
}
