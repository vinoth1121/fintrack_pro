import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/financial_calculators.dart';
import '../widgets/calculator_components.dart';

class EmiCalculatorView extends StatefulWidget {
  const EmiCalculatorView({super.key});

  @override
  State<EmiCalculatorView> createState() => _EmiCalculatorViewState();
}

class _EmiCalculatorViewState extends State<EmiCalculatorView> {
  final _principalController = TextEditingController(text: '250000');
  final _rateController = TextEditingController(text: '8.5');
  final _tenureController = TextEditingController(text: '60');

  EmiResult? _result;

  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _calculate();
    _principalController.addListener(_calculate);
    _rateController.addListener(_calculate);
    _tenureController.addListener(_calculate);
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_principalController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final tenure = int.tryParse(_tenureController.text) ?? 0;

    setState(() {
      _result = FinancialCalculators.calculateEmi(
        principal: principal,
        annualRatePercent: rate,
        tenureMonths: tenure,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        CalculatorDisplay(
          expression: 'Monthly Payment',
          result: _currencyFmt.format(_result?.monthlyPayment ?? 0),
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.xl),

        CalculatorInputRow(label: 'Loan Amount', controller: _principalController, suffix: '\$'),
        const SizedBox(height: AppSpacing.sm),
        CalculatorInputRow(label: 'Interest Rate', controller: _rateController, suffix: '% p.a.'),
        const SizedBox(height: AppSpacing.sm),
        CalculatorInputRow(label: 'Tenure', controller: _tenureController, suffix: 'months'),

        const SizedBox(height: AppSpacing.xl),

        if (_result != null && _result!.totalPayment > 0)
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.darkBorder, width: 0.5),
            ),
            child: Column(
              children: [
                CalculatorResultRow(label: 'Principal Amount', value: _currencyFmt.format(double.tryParse(_principalController.text) ?? 0)),
                CalculatorResultRow(label: 'Total Interest', value: _currencyFmt.format(_result!.totalInterest), valueColor: AppColors.warning),
                const Divider(color: AppColors.darkDivider, height: AppSpacing.lg),
                CalculatorResultRow(label: 'Total Payment', value: _currencyFmt.format(_result!.totalPayment), emphasized: true),
              ],
            ),
          ),

        if (_result != null && _result!.totalPayment > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          _PrincipalInterestBar(
            principal: double.tryParse(_principalController.text) ?? 0,
            interest: _result!.totalInterest,
          ),
        ],
      ],
    );
  }
}

class _PrincipalInterestBar extends StatelessWidget {
  final double principal;
  final double interest;

  const _PrincipalInterestBar({required this.principal, required this.interest});

  @override
  Widget build(BuildContext context) {
    final total = principal + interest;
    final principalPct = total > 0 ? principal / total : 0.5;

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
          Text('Principal vs Interest', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Row(
              children: [
                Expanded(flex: (principalPct * 100).round(), child: Container(height: 10, color: AppColors.primary)),
                Expanded(flex: 100 - (principalPct * 100).round(), child: Container(height: 10, color: AppColors.warning)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(color: AppColors.primary, label: 'Principal ${(principalPct * 100).toStringAsFixed(0)}%'),
              _LegendItem(color: AppColors.warning, label: 'Interest ${((1 - principalPct) * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
      ],
    );
  }
}
