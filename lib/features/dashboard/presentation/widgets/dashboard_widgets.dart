import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/dashboard_entities.dart';

// ════════════════════════════════════════════════════════════════
// QUICK STATS ROW
// ════════════════════════════════════════════════════════════════

class QuickStatsRow extends StatelessWidget {
  final double savingsRate;
  final double budgetUsed;
  final int subscriptions;
  final double subscriptionCost;

  const QuickStatsRow({
    super.key,
    required this.savingsRate,
    required this.budgetUsed,
    required this.subscriptions,
    required this.subscriptionCost,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Savings Rate',
            value: '${savingsRate.toStringAsFixed(1)}%',
            icon: Icons.savings_rounded,
            color: AppColors.secondary,
            progress: savingsRate / 100,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(
            label: 'Budget Used',
            value: '${budgetUsed.toStringAsFixed(0)}%',
            icon: Icons.account_balance_wallet_rounded,
            color: budgetUsed > 85 ? AppColors.error : AppColors.budget,
            progress: budgetUsed / 100,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(
            label: 'Subs',
            value: '\$${subscriptionCost.toStringAsFixed(0)}',
            icon: Icons.repeat_rounded,
            color: const Color(0xFFE040FB),
            subtitle: '$subscriptions active',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;
  final String? subtitle;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.darkTextTertiary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.amountSmall.copyWith(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.darkTextTertiary,
                fontSize: 9,
              ),
            ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                backgroundColor: AppColors.darkBorder,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW
// ════════════════════════════════════════════════════════════════

class QuickActionsRow extends StatelessWidget {
  QuickActionsRow({super.key});

  final List<_QuickAction> _actions = [
    _QuickAction(
      label: 'Add\nExpense',
      icon: Icons.remove_circle_outline_rounded,
      color: AppColors.expense,
      route: '/expenses/add',
    ),
    _QuickAction(
      label: 'Add\nIncome',
      icon: Icons.add_circle_outline_rounded,
      color: AppColors.income,
      route: '/income/add',
    ),
    _QuickAction(
      label: 'Budget',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.budget,
      route: AppRoutes.budget,
    ),
    _QuickAction(
      label: 'AI Chat',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.primary,
      route: AppRoutes.aiChat,
    ),
    _QuickAction(
      label: 'Scanner',
      icon: Icons.document_scanner_rounded,
      color: const Color(0xFF00BCD4),
      route: AppRoutes.scanReceipt,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _actions.map((a) {
        return GestureDetector(
          onTap: () => context.push(a.route),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  border: Border.all(
                    color: a.color.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Icon(a.icon, color: a.color, size: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                a.label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.darkTextSecondary,
                  fontSize: 10,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAction {
  final String label, icon_, route;
  final IconData icon;
  final Color color;
  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  }) : icon_ = '';
}

// ════════════════════════════════════════════════════════════════
// AI INSIGHT BANNER
// ════════════════════════════════════════════════════════════════

class AiInsightBanner extends StatelessWidget {
  final String insight;
  const AiInsightBanner({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Insight',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.darkTextSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SPENDING CHART CARD
// ════════════════════════════════════════════════════════════════

class SpendingChartCard extends StatefulWidget {
  final List<double> weeklyData;
  const SpendingChartCard({super.key, required this.weeklyData});

  @override
  State<SpendingChartCard> createState() => _SpendingChartCardState();
}

class _SpendingChartCardState extends State<SpendingChartCard> {
  int? _touchedIndex;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxY = (widget.weeklyData.reduce((a, b) => a > b ? a : b) * 1.3);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Spending',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkCardElevated,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.darkBorder, width: 0.5),
                ),
                child: Text(
                  'This Week',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent) {
                      setState(() {
                        _touchedIndex = response?.spot?.touchedBarGroupIndex;
                      });
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.darkCardElevated,
                    tooltipRoundedRadius: AppRadius.sm,
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      return BarTooltipItem(
                        '\$${widget.weeklyData[gIdx].toStringAsFixed(0)}',
                        AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            _days[idx],
                            style: AppTypography.labelSmall.copyWith(
                              color: _touchedIndex == idx
                                  ? AppColors.primary
                                  : AppColors.darkTextTertiary,
                              fontWeight: _touchedIndex == idx
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.darkDivider,
                    strokeWidth: 0.5,
                    dashArray: [4, 4],
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(widget.weeklyData.length, (i) {
                  final isTouched = _touchedIndex == i;
                  final isHighest = widget.weeklyData[i] ==
                      widget.weeklyData.reduce((a, b) => a > b ? a : b);

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: widget.weeklyData[i],
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          colors: isTouched || isHighest
                              ? [AppColors.primary, AppColors.primaryLight]
                              : [
                                  AppColors.primary.withValues(alpha: 0.4),
                                  AppColors.primary.withValues(alpha: 0.25),
                                ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FINANCIAL HEALTH CARD
// ════════════════════════════════════════════════════════════════

class FinancialHealthCard extends StatelessWidget {
  final FinancialHealthEntity health;
  const FinancialHealthCard({super.key, required this.health});

  Color get _scoreColor {
    if (health.score >= 80) return AppColors.success;
    if (health.score >= 60) return AppColors.budget;
    return AppColors.error;
  }

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Health',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Based on your activity this month',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Score circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _scoreColor, width: 2.5),
                  color: _scoreColor.withValues(alpha: 0.08),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${health.score}',
                      style: AppTypography.titleMedium.copyWith(
                        color: _scoreColor,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      health.grade,
                      style: AppTypography.labelSmall.copyWith(
                        color: _scoreColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: health.score / 100,
              backgroundColor: AppColors.darkBorder,
              valueColor: AlwaysStoppedAnimation(_scoreColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Tips
          ...health.tips.take(2).map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: AppColors.budget,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    tip,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.darkTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TOP CATEGORIES CARD
// ════════════════════════════════════════════════════════════════

class TopCategoriesCard extends StatelessWidget {
  final List<SpendingCategoryEntity> categories;
  const TopCategoriesCard({super.key, required this.categories});

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
        children: categories.asMap().entries.map((e) {
          final i = e.key;
          final cat = e.value;
          final color = Color(
            int.parse(cat.color.replaceFirst('#', '0xFF')),
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        _iconForCategory(cat.icon),
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat.name,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.darkTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _fmt.format(cat.amount),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.darkTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                  child: LinearProgressIndicator(
                                    value: cat.percentage / 100,
                                    backgroundColor: AppColors.darkBorder,
                                    valueColor: AlwaysStoppedAnimation(color),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${cat.percentage.toStringAsFixed(1)}%',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.darkTextTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < categories.length - 1)
                const Divider(
                  color: AppColors.darkDivider,
                  thickness: 0.5,
                  height: 1,
                  indent: AppSpacing.base,
                  endIndent: AppSpacing.base,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForCategory(String icon) {
    return switch (icon) {
      'restaurant' => Icons.restaurant_rounded,
      'car' => Icons.directions_car_rounded,
      'movie' => Icons.movie_rounded,
      'bag' => Icons.shopping_bag_rounded,
      'flash' => Icons.flash_on_rounded,
      _ => Icons.category_rounded,
    };
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT TRANSACTIONS LIST
// ════════════════════════════════════════════════════════════════

class RecentTransactionsList extends StatelessWidget {
  final List<RecentTransactionEntity> transactions;
  const RecentTransactionsList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        children: transactions.asMap().entries.map((e) {
          final i = e.key;
          final tx = e.value;
          return _TransactionTile(
            transaction: tx,
            showDivider: i < transactions.length - 1,
          );
        }).toList(),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final RecentTransactionEntity transaction;
  final bool showDivider;

  const _TransactionTile({
    required this.transaction,
    required this.showDivider,
  });

  static final _amtFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(transaction.color?.replaceFirst('#', '0xFF') ?? '0xFF6C63FF'),
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(AppRadius.base),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      transaction.isExpense
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: transaction.isExpense
                          ? AppColors.expense
                          : AppColors.income,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Title & category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                transaction.category,
                                style: AppTypography.labelSmall.copyWith(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _timeAgo(transaction.date),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.darkTextTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    '${transaction.isExpense ? '-' : '+'}'
                    '${_amtFmt.format(transaction.amount)}',
                    style: AppTypography.amountSmall.copyWith(
                      color: transaction.isExpense
                          ? AppColors.expense
                          : AppColors.income,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            color: AppColors.darkDivider,
            thickness: 0.5,
            height: 1,
            indent: AppSpacing.base,
            endIndent: AppSpacing.base,
          ),
      ],
    );
  }
}
