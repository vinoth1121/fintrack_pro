import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// Analytics — mirrors the web app's `views/analytics.tsx`.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final d = ref.watch(derivedProvider);
    final currency = state.profile.baseCurrency;

    final health = financialHealthScore(
      income: d.monthIncome,
      expenses: d.monthExpenses,
      budgetsOver: d.budgetsOver,
      budgetsTotal: d.budgetUsage.length,
      goalsOnTrack: d.goalsOnTrack,
      goalsTotal: d.goalsTotal,
    );
    final healthColor = health.score >= 70
        ? AppColors.success
        : health.score >= 50
            ? AppColors.warning
            : AppColors.error;
    final gradeLabel = _gradeLabel(health.label, t);
    final gradeTitle = '${t.analytics.grade} ${health.grade} · $gradeLabel';

    final topCategories = d.categoryBreakdown.take(6).toList();
    final chartData = d.trend
        .map((p) => _TrendPoint(p.month, p.income, p.expense))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _HealthHero(
                  score: health.score,
                  gradeTitle: gradeTitle,
                  healthColor: healthColor,
                  pill: t.analytics.financialHealth,
                  description:
                      'Your score blends savings rate, budget adherence, and goal progress. Keep it above 70 for a strong financial position.',
                  savingsRateLabel: t.analytics.savingsRate,
                  savingsRate: d.savingsRate,
                  budgetsOnTrack: d.budgetUsage.length - d.budgetsOver,
                  budgetsTotal: d.budgetUsage.length,
                  goalsOnTrack: d.goalsOnTrack,
                  goalsTotal: d.goalsTotal,
                  onTrackShort: t.dashboard.onTrackShort,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _statRow(context, t, d, currency),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _DonutAndTopCategories(
                  t: t,
                  currency: currency,
                  monthExpenses: d.monthExpenses,
                  topCategories: topCategories,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _IncomeVsExpenseCard(
                  t: t,
                  currency: currency,
                  data: chartData,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _CashFlowCard(
                  t: t,
                  currency: currency,
                  data: chartData,
                ).animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
      BuildContext context, AppT t, DerivedData d, String currency,) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 720 ? 4 : 2;
        final tiles = <Widget>[
          StatTile(
            label: t.analytics.totalIncome,
            icon: const Icon(Icons.trending_up),
            accent: 'green',
            value: Text(formatMoney(d.totalIncome, currency, compact: true)),
          ),
          StatTile(
            label: t.analytics.totalExpenses,
            icon: const Icon(Icons.trending_down),
            accent: 'amber',
            value: Text(formatMoney(d.totalExpenses, currency, compact: true)),
          ),
          StatTile(
            label: t.analytics.netBalance,
            icon: const Icon(Icons.stacked_line_chart),
            accent: 'iris',
            value: Text(formatMoney(d.netBalance, currency, compact: true)),
          ),
          StatTile(
            label: t.analytics.savingsRate,
            accent: 'cyan',
            value: Text('${(d.savingsRate * 100).round()}%'),
          ),
        ];
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: tiles,
        );
      },
    );
  }

  String _gradeLabel(String label, AppT t) {
    switch (label) {
      case 'Excellent':
        return t.analytics.excellent;
      case 'Great':
        return t.analytics.great;
      case 'Good':
        return t.analytics.good;
      case 'Fair':
        return t.analytics.fair;
      default:
        return t.analytics.needsWork;
    }
  }
}

class _HealthHero extends StatelessWidget {
  final int score;
  final String gradeTitle;
  final Color healthColor;
  final String pill, description;
  final String savingsRateLabel;
  final double savingsRate;
  final int budgetsOnTrack, budgetsTotal, goalsOnTrack, goalsTotal;
  final String onTrackShort;

  const _HealthHero({
    required this.score,
    required this.gradeTitle,
    required this.healthColor,
    required this.pill,
    required this.description,
    required this.savingsRateLabel,
    required this.savingsRate,
    required this.budgetsOnTrack,
    required this.budgetsTotal,
    required this.goalsOnTrack,
    required this.goalsTotal,
    required this.onTrackShort,
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
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  healthColor.withValues(alpha: 0.25),
                  Colors.transparent,
                ],),
              ),
            ),
          ),
          Row(
            children: [
              ProgressRing(
                value: score.toDouble(),
                size: 120,
                stroke: 11,
                color: healthColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: AppTypography.amount(context,
                                size: 26, weight: FontWeight.bold,)
                            .copyWith(height: 1.0),),
                    Text('/ 100',
                        style: AppTypography.label(context, size: 9)
                            .copyWith(
                                color: l.mutedForeground,
                                letterSpacing: 1.2,),),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed, size: 12),
                          const SizedBox(width: 4),
                          Text(pill),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(gradeTitle,
                        style: AppTypography.display(context, size: 19),),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: AppTypography.body(context, size: 12)
                          .copyWith(color: l.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          '$savingsRateLabel ${(savingsRate * 100).round()}%',
                          style: AppTypography.body(context,
                                  size: 11, weight: FontWeight.w600,)
                              .copyWith(color: AppColors.success),
                        ),
                        Text(
                          'Budgets $budgetsOnTrack/$budgetsTotal $onTrackShort',
                          style: AppTypography.body(context,
                                  size: 11, weight: FontWeight.w600,)
                              .copyWith(color: AppColors.iris),
                        ),
                        Text(
                          'Goals $goalsOnTrack/$goalsTotal $onTrackShort',
                          style: AppTypography.body(context,
                                  size: 11, weight: FontWeight.w600,)
                              .copyWith(color: AppColors.cyan),
                        ),
                      ],
                    ),
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

class _DonutAndTopCategories extends StatelessWidget {
  final AppT t;
  final String currency;
  final double monthExpenses;
  final List<CategoryBreakdown> topCategories;
  const _DonutAndTopCategories({
    required this.t,
    required this.currency,
    required this.monthExpenses,
    required this.topCategories,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final children = <Widget>[
          _donutCard(context),
          _topCategoriesCard(context),
        ];
        return wide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: children[0]),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: children[1]),
                  ],
                ),
              )
            : Column(children: children);
      },
    );
  }

  Widget _donutCard(BuildContext context) {
    final l = context.lumina;
    final data = topCategories
        .asMap()
        .entries
        .map((e) => _DonutSlice(
              e.value.name,
              e.value.amount,
              _hexColor(e.value.color),
            ),)
        .toList();
    if (data.isEmpty) {
      data.add(_DonutSlice('—', 1, l.surface3));
    }
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: t.analytics.spendingByCategory, subtitle: t.common.thisMonth),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices: data,
                      backgroundColor: l.surface3.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.analytics.totalExpenses,
                        style: AppTypography.label(context, size: 10)
                            .copyWith(color: l.mutedForeground),),
                    const SizedBox(height: 2),
                    Text(formatMoney(monthExpenses, currency, compact: true),
                        style: AppTypography.amount(context, size: 18, weight: FontWeight.bold)
                            .copyWith(height: 1.0),),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final e in topCategories)
                _LegendDot(
                  color: _hexColor(e.color),
                  label: e.name,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topCategoriesCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
              title: t.analytics.topCategories,
              subtitle: t.analytics.whereMoneyGoes,),
          const SizedBox(height: 14),
          ...topCategories.asMap().entries.map((e) {
            final c = e.value;
            final color = _hexColor(c.color);
            return Padding(
              padding: EdgeInsets.only(top: e.key == 0 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconFor(c.icon), color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c.name,
                                style: AppTypography.body(context,
                                        size: 13, weight: FontWeight.w500,)
                                    .copyWith(height: 1.1),),
                            Text(formatMoney(c.amount, currency),
                                style: AppTypography.body(context,
                                        size: 12, weight: FontWeight.w500,)
                                    .copyWith(
                                        color: context.lumina.mutedForeground,),),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (c.pct / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: context.lumina.surface3,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                            .animate(delay: (200 + e.key * 50).ms)
                            .fadeIn(duration: 500.ms),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text('${c.pct}%',
                        textAlign: TextAlign.right,
                        style: AppTypography.body(context,
                                size: 11, weight: FontWeight.w600,)
                            .copyWith(color: context.lumina.mutedForeground),),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _IncomeVsExpenseCard extends StatelessWidget {
  final AppT t;
  final String currency;
  final List<_TrendPoint> data;
  const _IncomeVsExpenseCard({required this.t, required this.currency, required this.data});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: t.analytics.incomeVsExpenses, subtitle: t.analytics.last6Months),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: AppColors.success, label: t.nav.income),
              const SizedBox(width: 14),
              _LegendDot(color: AppColors.error, label: t.nav.expenses),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: CustomPaint(
              painter: _BarChartPainter(
                data: data,
                incomeColor: AppColors.success,
                expenseColor: AppColors.error,
                gridColor: l.border.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  final AppT t;
  final String currency;
  final List<_TrendPoint> data;
  const _CashFlowCard({required this.t, required this.currency, required this.data});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: t.analytics.cashFlowTrend, subtitle: t.analytics.netPerMonth),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _LineChartPainter(
                data: data,
                lineColor: AppColors.iris,
                gridColor: l.border.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final Color backgroundColor;

  const _DonutPainter({required this.slices, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, radius, backgroundPaint);

    final total = slices.fold<double>(1, (sum, slice) => sum + slice.value);
    var startAngle = -90 * (math.pi / 180);
    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.slices != slices || oldDelegate.backgroundColor != backgroundColor;
}

class _BarChartPainter extends CustomPainter {
  final List<_TrendPoint> data;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;

  const _BarChartPainter({required this.data, required this.incomeColor, required this.expenseColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;
    final maxValue = data.fold<double>(1, (prev, point) => math.max(prev, math.max(point.income, point.expense))) * 1.1;

    for (var i = 0; i < 4; i++) {
      final y = 12 + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barWidth = chartWidth / math.max(1, data.length * 3);
    for (var i = 0; i < data.length; i++) {
      final point = data[i];
      final x = 12 + (barWidth * 1.5 * i) + (barWidth * 0.15);
      final incomeHeight = (point.income / maxValue) * chartHeight;
      final expenseHeight = (point.expense / maxValue) * chartHeight;
      canvas.drawRect(Rect.fromLTWH(x, size.height - 12 - incomeHeight, barWidth * 0.3, incomeHeight), Paint()..color = incomeColor);
      canvas.drawRect(Rect.fromLTWH(x + barWidth * 0.4, size.height - 12 - expenseHeight, barWidth * 0.3, expenseHeight), Paint()..color = expenseColor);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.incomeColor != incomeColor || oldDelegate.expenseColor != expenseColor || oldDelegate.gridColor != gridColor;
}

class _LineChartPainter extends CustomPainter {
  final List<_TrendPoint> data;
  final Color lineColor;
  final Color gridColor;

  const _LineChartPainter({required this.data, required this.lineColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    final linePaint = Paint()..color = lineColor..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;
    final maxValue = data.fold<double>(1, (prev, point) => math.max(prev, point.net.abs())) * 1.1;

    for (var i = 0; i < 4; i++) {
      final y = 12 + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = 12 + (chartWidth * i) / (data.length - 1).clamp(1, 999999);
      final y = size.height - 12 - ((data[i].net / maxValue) * chartHeight).clamp(-chartHeight, chartHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.lineColor != lineColor || oldDelegate.gridColor != gridColor;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppTypography.body(context, size: 11)
                .copyWith(color: context.lumina.mutedForeground),),
      ],
    );
  }
}

class _DonutSlice {
  final String label;
  final double value;
  final Color color;
  const _DonutSlice(this.label, this.value, this.color);
}

class _TrendPoint {
  final String month;
  final double income;
  final double expense;
  const _TrendPoint(this.month, this.income, this.expense);
  double get net => income - expense;
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
  };
  return m[name] ?? Icons.category;
}
