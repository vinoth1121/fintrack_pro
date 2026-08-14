import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/financial_calculators.dart';
import '../widgets/calculator_components.dart';

class SavingsCalculatorView extends StatefulWidget {
  const SavingsCalculatorView({super.key});

  @override
  State<SavingsCalculatorView> createState() => _SavingsCalculatorViewState();
}

class _SavingsCalculatorViewState extends State<SavingsCalculatorView> {
  final _initialController = TextEditingController(text: '5000');
  final _monthlyController = TextEditingController(text: '500');
  final _rateController = TextEditingController(text: '7');
  final _yearsController = TextEditingController(text: '10');

  SavingsResult? _result;

  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculate();
    for (final c in [_initialController, _monthlyController, _rateController, _yearsController]) {
      c.addListener(_calculate);
    }
  }

  @override
  void dispose() {
    _initialController.dispose();
    _monthlyController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _result = FinancialCalculators.calculateSavings(
        initialAmount: double.tryParse(_initialController.text) ?? 0,
        monthlyContribution: double.tryParse(_monthlyController.text) ?? 0,
        annualRatePercent: double.tryParse(_rateController.text) ?? 0,
        years: int.tryParse(_yearsController.text) ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        CalculatorDisplay(
          expression: 'Projected Final Balance',
          result: _currencyFmt.format(_result?.finalAmount ?? 0),
          accentColor: AppColors.income,
        ),
        const SizedBox(height: AppSpacing.xl),

        CalculatorInputRow(label: 'Initial Amount', controller: _initialController, suffix: '\$'),
        const SizedBox(height: AppSpacing.sm),
        CalculatorInputRow(label: 'Monthly Contribution', controller: _monthlyController, suffix: '\$'),
        const SizedBox(height: AppSpacing.sm),
        CalculatorInputRow(label: 'Expected Return', controller: _rateController, suffix: '% p.a.'),
        const SizedBox(height: AppSpacing.sm),
        CalculatorInputRow(label: 'Time Horizon', controller: _yearsController, suffix: 'years'),

        const SizedBox(height: AppSpacing.xl),

        if (_result != null && _result!.yearlyBreakdown.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.darkBorder, width: 0.5),
            ),
            child: Column(
              children: [
                CalculatorResultRow(label: 'Total Contributions', value: _currencyFmt.format(_result!.totalContributions)),
                CalculatorResultRow(label: 'Interest Earned', value: _currencyFmt.format(_result!.totalInterestEarned), valueColor: AppColors.income),
                const Divider(color: AppColors.darkDivider, height: AppSpacing.lg),
                CalculatorResultRow(label: 'Final Balance', value: _currencyFmt.format(_result!.finalAmount), emphasized: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _GrowthChart(breakdown: _result!.yearlyBreakdown),
        ],
      ],
    );
  }
}

class _GrowthChart extends StatelessWidget {
  final List<SavingsYearEntry> breakdown;
  const _GrowthChart({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final maxBalance = breakdown.map((e) => e.balance).reduce((a, b) => a > b ? a : b);

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
          Text('Growth Over Time', style: AppTypography.titleSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxBalance * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxBalance / 4,
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
                      interval: breakdown.length > 10 ? (breakdown.length / 5).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= breakdown.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text('Y${breakdown[idx].year}', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: breakdown.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.balance)).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.income,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.income.withValues(alpha: 0.2), AppColors.income.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    );
  }
}
