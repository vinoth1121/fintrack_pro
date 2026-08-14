import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// Dashboard — live financial overview.
/// Mirrors the web `views/dashboard.tsx`: hero balance card with aurora gradient,
/// 4 stat tiles, 7-day spend sparkline (SfCartesianChart area series), AI insight
/// card, budget health bars, recent transactions list, and savings goals preview.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final d = ref.watch(derivedProvider);
    final s = ref.watch(fintrackProvider);
    final currency = s.profile.baseCurrency;
    final l = context.lumina;

    final recent = s.transactions.take(5).toList();
    final insight = _pickInsight(d);
    final goals = s.goals.take(4).toList();
    final r = Resp(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Hero balance card ─────────────────────────────────
              _HeroBalanceCard(
                currency: currency,
                netBalance: d.netBalance,
                monthIncome: d.monthIncome,
                monthExpenses: d.monthExpenses,
                savingsRate: d.savingsRate,
                onExpense: () => context.go('/expenses'),
                onIncome: () => context.go('/income'),
                t: t,
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms),
              const SizedBox(height: 20),

              // ─── Stat tiles ────────────────────────────────────────
              _StatTileGrid(
                wide: wide,
                tiles: [
                  _StatData(
                    label: t.dashboard.monthIncome,
                    value: formatMoney(d.monthIncome, currency, compact: true),
                    delta: '${d.incomeDelta.abs().round()}% ${t.dashboard.vsLast}',
                    deltaPositive: d.incomeDelta >= 0,
                    icon: Icons.trending_up_rounded,
                    accent: 'green',
                  ),
                  _StatData(
                    label: t.dashboard.monthSpend,
                    value: formatMoney(d.monthExpenses, currency, compact: true),
                    delta: '${d.expenseDelta.abs().round()}% ${t.dashboard.vsLast}',
                    deltaPositive: d.expenseDelta <= 0,
                    icon: Icons.wallet_outlined,
                    accent: 'amber',
                  ),
                  _StatData(
                    label: t.dashboard.savingsRate,
                    value: '${(d.savingsRate * 100).round()}%',
                    icon: Icons.savings_outlined,
                    accent: 'iris',
                  ),
                  _StatData(
                    label: t.dashboard.activeBudgets,
                    value: '${s.budgets.length}',
                    delta: d.budgetsOver > 0 ? '${d.budgetsOver} ${t.dashboard.overLimit}' : t.dashboard.allOnTrack,
                    deltaPositive: d.budgetsOver == 0,
                    icon: Icons.account_balance_wallet_outlined,
                    accent: d.budgetsOver > 0 ? 'red' : 'cyan',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Sparkline + AI insight ────────────────────────────
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: _SparklineCard(d: d, t: t, l: l, currency: currency)),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _AiInsightCard(text: insight, t: t, l: l)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _SparklineCard(d: d, t: t, l: l, currency: currency, r: r),
                    const SizedBox(height: 16),
                    _AiInsightCard(text: insight, t: t, l: l),
                  ],
                ),
              const SizedBox(height: 20),

              // ─── Budget health + recent transactions ───────────────
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _BudgetHealthCard(d: d, t: t, l: l, currency: currency)),
                      const SizedBox(width: 16),
                      Expanded(child: _RecentTxsCard(transactions: recent, t: t, l: l, currency: currency, state: s)),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _BudgetHealthCard(d: d, t: t, l: l, currency: currency),
                    const SizedBox(height: 16),
                    _RecentTxsCard(transactions: recent, t: t, l: l, currency: currency, state: s),
                  ],
                ),
              const SizedBox(height: 20),

              // ─── Savings goals preview ─────────────────────────────
                  _SavingsGoalsCard(goals: goals, d: d, t: t, l: l, currency: currency, r: r),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero balance card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBalanceCard extends StatelessWidget {
  final String currency;
  final double netBalance, monthIncome, monthExpenses, savingsRate;
  final VoidCallback onExpense, onIncome;
  final AppT t;

  const _HeroBalanceCard({
    required this.currency,
    required this.netBalance,
    required this.monthIncome,
    required this.monthExpenses,
    required this.savingsRate,
    required this.onExpense,
    required this.onIncome,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.iris.withValues(alpha: 0.22),
            AppColors.cyan.withValues(alpha: 0.12),
            l.surface3.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: l.border, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live overview pill
          GradientPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(duration: 1200.ms, begin: 0.3, end: 1.0),
                Text(t.dashboard.liveOverview, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t.dashboard.totalNetWorth,
            style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground),
          ),
          const SizedBox(height: 4),
          _AnimatedAmount(target: netBalance, currency: currency),
          const SizedBox(height: 14),
          // Money in / out / saved row
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _flowChip(
                icon: Icons.south_west_rounded,
                color: AppColors.success,
                text: '${formatMoney(monthIncome, currency, compact: true)} ${t.dashboard.moneyIn}',
              ),
              _flowChip(
                icon: Icons.north_east_rounded,
                color: AppColors.error,
                text: '${formatMoney(monthExpenses, currency, compact: true)} ${t.dashboard.moneyOut}',
              ),
              _flowChip(
                icon: Icons.savings_outlined,
                color: l.mutedForeground,
                text: '${t.dashboard.saved} ${(savingsRate * 100).round()}% · ${t.common.thisMonth}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Buttons row
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  onPressed: onExpense,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  child: Text(t.common.expense),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  onPressed: onIncome,
                  icon: const Icon(Icons.south_west_rounded, size: 16, color: AppColors.success),
                  child: Text(t.common.income),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowChip({required IconData icon, required Color color, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _AnimatedAmount extends StatefulWidget {
  final double target;
  final String currency;
  const _AnimatedAmount({required this.target, required this.currency});

  @override
  State<_AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<_AnimatedAmount> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = Tween<double>(begin: 0, end: widget.target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _animation = Tween<double>(begin: _animation.value, end: widget.target)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Resp(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (c, _) => Text(
        formatMoney(_animation.value, widget.currency),
        style: AppTypography.amount(context, size: r.font(38), weight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat tiles grid
// ─────────────────────────────────────────────────────────────────────────────
class _StatData {
  final String label, value;
  final String? delta;
  final bool deltaPositive;
  final IconData icon;
  final String accent;
  const _StatData({
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive = true,
    required this.icon,
    required this.accent,
  });
}

class _StatTileGrid extends StatelessWidget {
  final bool wide;
  final List<_StatData> tiles;
  const _StatTileGrid({required this.wide, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final count = wide ? 4 : 2;
    final ratio = wide ? 1.05 : 1.25;
    return GridView.count(
      crossAxisCount: count,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: ratio,
      children: [
        for (var i = 0; i < tiles.length; i++)
          fadeIn(
            StatTile(
              label: tiles[i].label,
              value: Text(tiles[i].value),
              delta: tiles[i].delta,
              deltaPositive: tiles[i].deltaPositive,
              icon: Icon(tiles[i].icon, size: 16),
              accent: tiles[i].accent,
            ),
            delay: Duration(milliseconds: 50 * i),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-day spending sparkline (SfCartesianChart)
// ─────────────────────────────────────────────────────────────────────────────
class _SparklineCard extends StatelessWidget {
  final DerivedData d;
  final AppT t;
  final LuminaColors l;
  final String currency;
  final Resp? r;
  const _SparklineCard({required this.d, required this.t, required this.l, required this.currency, this.r});

  @override
  Widget build(BuildContext context) {
    final h = r?.chart(180) ?? 180.0;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: t.dashboard.spending7day,
            subtitle: t.dashboard.dailyExpenseFlow,
            action: GestureDetector(
              onTap: () => context.go('/analytics'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.nav.analytics,
                    style: AppTypography.body(context, size: 12, weight: FontWeight.w500).copyWith(color: AppColors.iris),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.iris),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
            SizedBox(
              height: h,
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: d.sparkline,
                  lineColor: AppColors.iris,
                  fillColor: AppColors.iris.withValues(alpha: 0.18),
                  gridColor: l.border.withValues(alpha: 0.4),
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 250.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 250.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI insight card
// ─────────────────────────────────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<SparkPoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _SparklinePainter({required this.points, required this.lineColor, required this.fillColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final fillPaint = Paint()..color = fillColor;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final maxValue = points.map((p) => p.expense).fold<double>(1, (prev, value) => prev > value ? prev : value) * 1.1;
    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;

    for (var i = 0; i < 3; i++) {
      final y = 12 + (chartHeight / 2) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = 12 + (chartWidth * i) / (points.length - 1).clamp(1, 999999);
      final y = size.height - 12 - (points[i].expense / maxValue) * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 12);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width - 12, size.height - 12);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor || oldDelegate.fillColor != fillColor || oldDelegate.gridColor != gridColor;
  }
}

class _AiInsightCard extends StatelessWidget {
  final String text;
  final AppT t;
  final LuminaColors l;
  const _AiInsightCard({required this.text, required this.t, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.iris.withValues(alpha: 0.16),
            AppColors.cyan.withValues(alpha: 0.08),
            l.surface2.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.iris.withValues(alpha: 0.22),
                ),
                child: const Icon(Icons.psychology, size: 18, color: AppColors.iris),
              ),
              const SizedBox(width: 10),
              Text(t.dashboard.aiInsight, style: AppTypography.heading(context, size: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: AppTypography.body(context, size: 13).copyWith(height: 1.55),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/insights'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.dashboard.viewAllInsights,
                  style: AppTypography.body(context, size: 12, weight: FontWeight.w600).copyWith(color: AppColors.iris),
                ),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.iris),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget health bars
// ─────────────────────────────────────────────────────────────────────────────
class _BudgetHealthCard extends StatelessWidget {
  final DerivedData d;
  final AppT t;
  final LuminaColors l;
  final String currency;
  const _BudgetHealthCard({required this.d, required this.t, required this.l, required this.currency});

  @override
  Widget build(BuildContext context) {
    final usage = d.budgetUsage.take(4).toList();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: t.dashboard.budgetHealth,
            subtitle: t.common.thisMonth,
            action: GestureDetector(
              onTap: () => context.go('/budget'),
              child: Text(t.common.manage, style: AppTypography.body(context, size: 12, weight: FontWeight.w500).copyWith(color: AppColors.iris)),
            ),
          ),
          const SizedBox(height: 16),
          if (usage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '${t.budget.noBudgets}.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < usage.length; i++) ...[
                  _BudgetBar(u: usage[i], currency: currency, l: l),
                  if (i < usage.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 350.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 350.ms);
  }
}

class _BudgetBar extends StatelessWidget {
  final BudgetUsage u;
  final String currency;
  final LuminaColors l;
  const _BudgetBar({required this.u, required this.currency, required this.l});

  @override
  Widget build(BuildContext context) {
    final color = u.over
        ? AppColors.error
        : (u.pct >= 80 ? AppColors.warning : AppColors.success);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(u.categoryName, style: AppTypography.body(context, size: 13, weight: FontWeight.w500)),
            Text(
              '${formatMoney(u.spent, currency, compact: true)} / ${formatMoney(u.limit, currency, compact: true)}',
              style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (u.pct.clamp(0, 100)) / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (c, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: l.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent transactions
// ─────────────────────────────────────────────────────────────────────────────
class _RecentTxsCard extends StatelessWidget {
  final List<Transaction> transactions;
  final AppT t;
  final LuminaColors l;
  final String currency;
  final FinTrackState state;
  const _RecentTxsCard({required this.transactions, required this.t, required this.l, required this.currency, required this.state});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: t.dashboard.recentTransactions,
            action: GestureDetector(
              onTap: () => context.go('/expenses'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.common.all, style: AppTypography.body(context, size: 12, weight: FontWeight.w500).copyWith(color: AppColors.iris)),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.iris),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < transactions.length; i++)
                fadeIn(
                  _TxRow(
                    tx: transactions[i],
                    currency: currency,
                    state: state,
                    l: l,
                    onTap: () => context.go('/expenses'),
                  ),
                  delay: Duration(milliseconds: 450 + i * 50),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 400.ms);
  }
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final String currency;
  final FinTrackState state;
  final LuminaColors l;
  final VoidCallback onTap;
  const _TxRow({required this.tx, required this.currency, required this.state, required this.l, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = state.categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => state.categories.last,
    );
    final isIncome = tx.type == TxType.income;
    final color = _hexColor(cat.color);
    final title = tx.merchant ?? cat.name;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(cat.icon), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body(context, size: 13, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(formatDate(tx.date, style: 'rel'), style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground)),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}${formatMoney(tx.amount, currency, compact: true)}',
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
// Savings goals preview
// ─────────────────────────────────────────────────────────────────────────────
class _SavingsGoalsCard extends StatelessWidget {
  final List<SavingsGoal> goals;
  final DerivedData d;
  final AppT t;
  final LuminaColors l;
  final String currency;
  const _SavingsGoalsCard({required this.goals, required this.d, required this.t, required this.l, required this.currency, required this.r});
  final Resp r;

  @override
  Widget build(BuildContext context) {
    final wide = r.isWide;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: t.dashboard.savingsGoals,
            subtitle: '${d.goalsOnTrack}/${d.goalsTotal} ${t.dashboard.onTrackShort}',
            action: GestureDetector(
              onTap: () => context.go('/goals'),
              child: Text(t.common.viewAll, style: AppTypography.body(context, size: 12, weight: FontWeight.w500).copyWith(color: AppColors.iris)),
            ),
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(t.goals.noGoals, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground)),
              ),
            )
          else
            GridView.count(
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                for (var i = 0; i < goals.length; i++)
                  fadeIn(_GoalTile(g: goals[i], currency: currency, l: l), delay: Duration(milliseconds: 500 + i * 50)),
              ],
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: 500.ms);
  }
}

class _GoalTile extends StatelessWidget {
  final SavingsGoal g;
  final String currency;
  final LuminaColors l;
  const _GoalTile({required this.g, required this.currency, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = pct(g.saved, g.target);
    final color = _hexColor(g.color);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: l.surface3.withValues(alpha: 0.4),
        border: Border.all(color: l.border.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ProgressRing(
                value: p.toDouble(),
                size: 50,
                stroke: 5,
                color: color,
                child: Text('$p%', style: AppTypography.amount(context, size: 10, weight: FontWeight.bold)),
              ),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withValues(alpha: 0.2),
                ),
                child: Icon(_iconFor(g.icon), size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(g.name, style: AppTypography.body(context, size: 13, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            '${formatMoney(g.saved, currency, compact: true)} / ${formatMoney(g.target, currency, compact: true)}',
            style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _pickInsight(DerivedData d) {
  if (d.budgetsOver > 0) {
    return "You've exceeded ${d.budgetsOver} budget${d.budgetsOver > 1 ? 's' : ''} this month. Reviewing discretionary categories could recover savings quickly. Tap to get a tailored cutback plan.";
  }
  if (d.savingsRate >= 0.3) {
    return "Excellent — you're saving ${(d.savingsRate * 100).round()}% of income. Consider routing surplus into your goals or an SIP to compound returns.";
  }
  if (d.expenseDelta > 15) {
    return "Spending is up ${d.expenseDelta.round()}% versus last month. Your top growth category deserves a quick review to stay on plan.";
  }
  return "Your finances look steady. Saving consistently and staying under budget will improve your financial health score. Ask me for a 30-day forecast.";
}

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
