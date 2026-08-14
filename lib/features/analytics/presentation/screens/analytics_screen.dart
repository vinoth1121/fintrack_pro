import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/analytics_entity.dart';
import '../providers/analytics_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int? _touchedPieIndex;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);

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
          'Analytics',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.status == AnalyticsStatus.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  AppShimmerCard(height: 280),
                  SizedBox(height: AppSpacing.xl),
                  AppShimmerCard(height: 220),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(analyticsProvider.notifier).load(),
              color: AppColors.primary,
              backgroundColor: AppColors.darkCard,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xxxl,
                ),
                children: [
                  // ── Spending Breakdown Pie ──────────────────────────────────
                  _SpendingBreakdownCard(
                    breakdown: state.categoryBreakdown,
                    touchedIndex: _touchedPieIndex,
                    onTouch: (i) => setState(() => _touchedPieIndex = i),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Quick Stats ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Avg. Monthly Income',
                          value: state.avgMonthlyIncome,
                          color: AppColors.income,
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Avg. Monthly Spend',
                          value: state.avgMonthlyExpenses,
                          color: AppColors.expense,
                          icon: Icons.trending_down_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Monthly Trend ────────────────────────────────────────────
                  _MonthlyTrendCard(trend: state.monthlyTrend),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Category List ────────────────────────────────────────────
                  const AppSectionHeader(
                    title: 'Category Breakdown',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CategoryBreakdownList(breakdown: state.categoryBreakdown),
                ],
              ),
            ),
    );
  }
}

// ─── Pie Chart Card ───────────────────────────────────────────────────────────

class _SpendingBreakdownCard extends StatelessWidget {
  final List<CategoryBreakdownEntity> breakdown;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  const _SpendingBreakdownCard({
    required this.breakdown,
    required this.touchedIndex,
    required this.onTouch,
  });

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const AppEmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: 'No spending data yet',
          subtitle: 'Add some expenses to see your breakdown.',
        ),
      );
    }

    final total = breakdown.fold(0.0, (sum, c) => sum + c.amount);
    final selected = touchedIndex != null && touchedIndex! < breakdown.length
        ? breakdown[touchedIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            'Spending Breakdown',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 56,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent || event is FlLongPressEnd) {
                          onTouch(response?.touchedSection?.touchedSectionIndex);
                        }
                      },
                    ),
                    sections: breakdown.asMap().entries.map((e) {
                      final i = e.key;
                      final cat = e.value;
                      final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                      final isTouched = touchedIndex == i;
                      return PieChartSectionData(
                        value: cat.amount,
                        color: color,
                        radius: isTouched ? 48 : 40,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),
                // Center label - removed duration from PieChart (not a valid parameter)
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected?.name ?? 'Total',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt.format(selected?.amount ?? total),
                      style: AppTypography.titleMedium.copyWith(
                        color: selected != null
                            ? Color(int.parse(selected.color.replaceFirst('#', '0xFF')))
                            : AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Legend
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: breakdown.take(6).map((cat) {
              final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(cat.name, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextSecondary, fontSize: 10)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.color, required this.icon});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: AppSpacing.sm),
          Text(_fmt.format(value), style: AppTypography.amountSmall.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Monthly Trend Card ────────────────────────────────────────────────────────

class _MonthlyTrendCard extends StatelessWidget {
  final List<MonthlyTrendEntity> trend;
  const _MonthlyTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxY = trend.map((t) => t.income > t.expenses ? t.income : t.expenses).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Income vs Expenses',
                style: AppTypography.titleSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const _LegendDot(color: AppColors.income, label: 'Income'),
              const SizedBox(width: AppSpacing.md),
              const _LegendDot(color: AppColors.expense, label: 'Expenses'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY / 4,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.darkDivider, strokeWidth: 0.5, dashArray: [4, 4]),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            trend[idx].month,
                            style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.darkCardElevated,
                    tooltipRoundedRadius: AppRadius.sm,
                  ),
                ),
                lineBarsData: [
                  _buildLine(trend.map((t) => t.income).toList(), AppColors.income),
                  _buildLine(trend.map((t) => t.expenses).toList(), AppColors.expense),
                ],
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) =>
            FlDotCirclePainter(radius: 3, color: color, strokeColor: AppColors.darkCard, strokeWidth: 2),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10)),
      ],
    );
  }
}

// ─── Category Breakdown List ───────────────────────────────────────────────────

class _CategoryBreakdownList extends StatelessWidget {
  final List<CategoryBreakdownEntity> breakdown;
  const _CategoryBreakdownList({required this.breakdown});

  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        children: breakdown.asMap().entries.map((e) {
          final i = e.key;
          final cat = e.value;
          final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Icon(_iconFor(cat.icon), color: color, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
                          Text('${cat.transactionCount} transactions', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_fmt.format(cat.amount), style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                        Text('${cat.percentage.toStringAsFixed(1)}%', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < breakdown.length - 1)
                const Divider(color: AppColors.darkDivider, thickness: 0.5, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
            ],
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'restaurant' => Icons.restaurant_rounded,
      'car' => Icons.directions_car_rounded,
      'bag' => Icons.shopping_bag_rounded,
      'movie' => Icons.movie_rounded,
      'flash' => Icons.flash_on_rounded,
      'health' => Icons.favorite_rounded,
      _ => Icons.category_rounded,
    };
  }
}
