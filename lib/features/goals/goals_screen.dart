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

/// Savings goals — mirrors the web app's `views/goals.tsx`.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final currency = state.profile.baseCurrency;
    final goals = state.goals;
    final totalTarget = goals.fold(0.0, (a, g) => a + g.target);
    final totalSaved = goals.fold(0.0, (a, g) => a + g.saved);
    final overallPct = pct(totalSaved, totalTarget);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _Hero(
                  pill: t.goals.savingsGoals,
                  caption: t.goals.totalSaved,
                  totalSaved: totalSaved,
                  totalTarget: totalTarget,
                  currency: currency,
                  pctValue: overallPct,
                  ofTargetLabel: t.goals.ofTarget,
                  onAdd: () => _showCreate(context),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            if (goals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: const Icon(Icons.flag_outlined),
                      title: t.goals.noGoals,
                      description: t.misc.setTargetWatchGrow,
                      action: GradientButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showCreate(context),
                        child: Text(t.goals.createGoal),
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
                    maxCrossAxisExtent: 480,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _GoalCard(
                      goal: goals[i],
                      currency: currency,
                      ofLabel: t.common.of,
                      toGoLabel: t.goals.toGo,
                      daysLeftLabel: t.goals.daysLeft,
                      addMoneyLabel: t.goals.addMoney,
                      goalReachedLabel: t.goals.goalReached,
                      onDelete: () {
                        ref.read(fintrackProvider.notifier).deleteGoal(goals[i].id);
                        showAppToast(context, t.messages.goalDeleted,
                            kind: ToastKind.success,);
                      },
                      onContribute: () => _showContribute(context, goals[i].id),
                    ).animate().fadeIn(
                      duration: 400.ms,
                      delay: (i * 60).ms,
                    ).slideY(begin: 0.05),
                    childCount: goals.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateGoalDialog(),
    );
  }

  void _showContribute(BuildContext context, String goalId) {
    showDialog<void>(
      context: context,
      builder: (_) => _ContributeDialog(goalId: goalId),
    );
  }
}

class _Hero extends StatelessWidget {
  final String pill, caption;
  final double totalSaved, totalTarget;
  final String currency;
  final int pctValue;
  final String ofTargetLabel;
  final VoidCallback onAdd;
  const _Hero({
    required this.pill,
    required this.caption,
    required this.totalSaved,
    required this.totalTarget,
    required this.currency,
    required this.pctValue,
    required this.ofTargetLabel,
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
                  AppColors.success.withValues(alpha: 0.22),
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
                          const Icon(Icons.flag_outlined, size: 12),
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
                            text: formatMoney(totalSaved, currency),
                            style: AppTypography.amount(context,
                                    size: 30, weight: FontWeight.bold,)
                                .copyWith(letterSpacing: -0.5),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: '/ ${formatMoney(totalTarget, currency)}',
                            style: AppTypography.amount(context,
                                    size: 16, weight: FontWeight.w500,)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$pctValue% $ofTargetLabel',
                        style: AppTypography.body(context,
                                size: 12, weight: FontWeight.w600,)
                            .copyWith(color: AppColors.success),),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GradientButton(
                icon: const Icon(Icons.add),
                onPressed: onAdd,
                child: const Text('New'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final String currency;
  final String ofLabel, toGoLabel, daysLeftLabel;
  final String addMoneyLabel, goalReachedLabel;
  final VoidCallback onDelete, onContribute;

  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.ofLabel,
    required this.toGoLabel,
    required this.daysLeftLabel,
    required this.addMoneyLabel,
    required this.goalReachedLabel,
    required this.onDelete,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final p = pct(goal.saved, goal.target);
    final done = goal.saved >= goal.target;
    final daysLeft = goal.deadline?.difference(DateTime.now()).inDays.clamp(0, 99999);
    final color = _hexColor(goal.color);

    return GlassCard(
      hover: true,
      padding: const EdgeInsets.all(16),
      border: done ? Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(goal.icon), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: AppTypography.heading(context, size: 15),),
                    if (daysLeft != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 12, color: AppColors.iris),
                          const SizedBox(width: 4),
                          Text('$daysLeft $daysLeftLabel',
                              style: AppTypography.body(context, size: 11)
                                  .copyWith(color: l.mutedForeground),),
                        ],
                      ),
                    ],
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
          const SizedBox(height: 12),
          Row(
            children: [
              ProgressRing(
                value: p.toDouble(),
                size: 78,
                stroke: 7,
                color: color,
                child: Text('$p%',
                    style: AppTypography.amount(context, size: 14, weight: FontWeight.bold)
                        .copyWith(height: 1.0),),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(goal.saved, currency),
                      style: AppTypography.amount(context, size: 22, weight: FontWeight.bold)
                          .copyWith(color: color),
                    ),
                    Text(
                      '$ofLabel ${formatMoney(goal.target, currency)}',
                      style: AppTypography.body(context, size: 11)
                          .copyWith(color: l.mutedForeground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoney((goal.target - goal.saved).clamp(0, double.infinity), currency)} $toGoLabel',
                      style: AppTypography.body(context, size: 11)
                          .copyWith(color: l.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(
            onPressed: onContribute,
            expanded: true,
            icon: Icon(done ? Icons.celebration : Icons.add),
            child: Text(done ? goalReachedLabel : addMoneyLabel),
          ),
          const SizedBox(height: 10),
          Row(
            children: [25, 50, 75, 100].map((m) {
              final reached = p >= m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: AnimatedContainer(
                    duration: 300.ms,
                    height: 4,
                    decoration: BoxDecoration(
                      color: reached ? color : l.surface3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CreateGoalDialog extends ConsumerStatefulWidget {
  const _CreateGoalDialog();

  @override
  ConsumerState<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<_CreateGoalDialog> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '100000');
  DateTime? _deadline;
  String _icon = _kGoalIcons.first.$1;
  String _color = _kGoalColors.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final t = ref.read(tProvider);
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || target <= 0) {
      showAppToast(context, t.messages.enterGoalTarget, kind: ToastKind.error);
      return;
    }
    ref.read(fintrackProvider.notifier).addGoal(SavingsGoal(
      id: uid('g_'),
      name: _nameCtrl.text.trim(),
      target: target,
      saved: 0,
      deadline: _deadline,
      icon: _icon,
      color: _color,
      createdAt: DateTime.now(),
    ),);
    showAppToast(context, 'Goal created 🎯', kind: ToastKind.success);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
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
                      child: Text(t.goals.createSavingsGoal,
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
                _Label(text: t.goals.goalName),
                const SizedBox(height: 6),
                _TextField(
                  controller: _nameCtrl,
                  hint: 'e.g. Japan Trip',
                ),
                const SizedBox(height: 12),
                _Label(text: t.goals.targetAmount),
                const SizedBox(height: 6),
                _TextField(
                  controller: _targetCtrl,
                  keyboardType: TextInputType.number,
                  amountStyle: true,
                ),
                const SizedBox(height: 12),
                _Label(text: t.goals.deadline),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: l.surface3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: l.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: AppColors.iris),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _deadline == null
                                ? 'Pick a date'
                                : formatDate(_deadline!, style: 'long'),
                            style: AppTypography.body(context, size: 13)
                                .copyWith(color: _deadline == null ? l.mutedForeground : l.foreground),
                          ),
                        ),
                        if (_deadline != null)
                          IconButton(
                            onPressed: () => setState(() => _deadline = null),
                            icon: const Icon(Icons.close, size: 14),
                            splashRadius: 14,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Label(text: t.goals.icon),
                const SizedBox(height: 6),
                _IconPicker(
                  selected: _icon,
                  items: _kGoalIcons,
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
                  child: Text(t.goals.createGoal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributeDialog extends ConsumerWidget {
  final String goalId;
  const _ContributeDialog({required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final currency = state.profile.baseCurrency;
    final goal = state.goals.firstWhere(
      (g) => g.id == goalId,
      orElse: () => state.goals.first,
    );
    final ctrl = TextEditingController(text: '5000');

    void save() {
      final v = double.tryParse(ctrl.text) ?? 0;
      if (v <= 0) {
        showAppToast(context, t.messages.enterValidAmount, kind: ToastKind.error);
        return;
      }
      ref.read(fintrackProvider.notifier).contributeGoal(goal.id, v);
      showAppToast(
        context,
        t.messages.addedToGoal
            .replaceAll('{amount}', formatMoney(v, currency))
            .replaceAll('{name}', goal.name),
        kind: ToastKind.success,
      );
      Navigator.of(context).maybePop();
    }

    final l = context.lumina;
    return Dialog(
      backgroundColor: l.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${t.goals.addMoney} — ${goal.name}',
                  style: AppTypography.heading(context, size: 16),),
              const SizedBox(height: 8),
              Text(
                '${formatMoney(goal.saved, currency)} / ${formatMoney(goal.target, currency)}',
                style: AppTypography.body(context, size: 13)
                    .copyWith(color: l.mutedForeground),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.amount(context, size: 22, weight: FontWeight.bold),
                decoration: _inputDecoration(l),
              ),
              const SizedBox(height: 12),
              Row(
                children: [1000, 5000, 10000, 25000].map((q) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: q == 25000 ? 0 : 6,),
                      child: _QuickAmount(
                        label: formatMoney(q.toDouble(), currency, compact: true),
                        onTap: () => ctrl.text = q.toString(),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              GradientButton(
                onPressed: save,
                expanded: true,
                child: Text(t.goals.addMoney),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(LuminaColors l) => InputDecoration(
        filled: true,
        fillColor: l.surface3.withValues(alpha: 0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

class _QuickAmount extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmount({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: l.surface3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: l.border, width: 1),
          ),
          child: Center(
            child: Text(label,
                style: AppTypography.body(context, size: 11, weight: FontWeight.w600),),
          ),
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
            width: 40,
            height: 40,
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
                size: 18,
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
      children: _kGoalColors.map((hex) {
        final color = _hexColor(hex);
        final isSel = hex == selected;
        return InkWell(
          onTap: () => onPicked(hex),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSel
                  ? Border.all(color: color, width: 3)
                  : null,
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
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ---- helpers ---------------------------------------------------------------

const _kGoalIcons = <(String, IconData)>[
  ('gps_fixed', Icons.gps_fixed),
  ('flight', Icons.flight),
  ('home', Icons.home),
  ('directions_car', Icons.directions_car),
  ('school', Icons.school),
  ('laptop', Icons.laptop),
  ('card_giftcard', Icons.card_giftcard),
  ('verified_user', Icons.verified_user),
  ('favorite', Icons.favorite),
  ('smartphone', Icons.smartphone),
];

const _kGoalColors = <String>[
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
    'gps_fixed': Icons.gps_fixed,
    'flight': Icons.flight,
    'home': Icons.home,
    'directions_car': Icons.directions_car,
    'school': Icons.school,
    'laptop': Icons.laptop,
    'card_giftcard': Icons.card_giftcard,
    'verified_user': Icons.verified_user,
    'favorite': Icons.favorite,
    'smartphone': Icons.smartphone,
    'target': Icons.gps_fixed,
    'wallet': Icons.account_balance_wallet,
    'movie': Icons.movie,
    'music_note': Icons.music_note,
    'cloud': Icons.cloud,
    'description': Icons.description,
    'palette': Icons.palette,
    'inventory_2': Icons.inventory_2_outlined,
  };
  return m[name] ?? Icons.flag_outlined;
}
