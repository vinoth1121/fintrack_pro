import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/financial_calculators.dart';
import '../widgets/calculator_components.dart';

class GstCalculatorView extends StatefulWidget {
  const GstCalculatorView({super.key});

  @override
  State<GstCalculatorView> createState() => _GstCalculatorViewState();
}

class _GstCalculatorViewState extends State<GstCalculatorView> {
  final _amountController = TextEditingController(text: '1000');
  double _rate = 18;
  bool _isInclusive = false;

  GstResult? _result;

  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static const _presetRates = [5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _calculate();
    _amountController.addListener(_calculate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _result = FinancialCalculators.calculateGst(amount: amount, ratePercent: _rate, isInclusive: _isInclusive);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        CalculatorDisplay(
          expression: _isInclusive ? 'Base Amount (excl. GST)' : 'Total Amount (incl. GST)',
          result: _currencyFmt.format(_isInclusive ? (_result?.baseAmount ?? 0) : (_result?.totalAmount ?? 0)),
          accentColor: AppColors.secondary,
        ),
        const SizedBox(height: AppSpacing.xl),

        CalculatorInputRow(label: 'Amount', controller: _amountController, suffix: '\$'),
        const SizedBox(height: AppSpacing.base),

        // Inclusive/Exclusive toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.darkBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(child: _ToggleButton(label: 'Add GST', isSelected: !_isInclusive, onTap: () => setState(() { _isInclusive = false; _calculate(); }))),
              Expanded(child: _ToggleButton(label: 'Remove GST', isSelected: _isInclusive, onTap: () => setState(() { _isInclusive = true; _calculate(); }))),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.base),

        Text('GST Rate', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: _presetRates.map((rate) {
            final isSelected = _rate == rate;
            return GestureDetector(
              onTap: () => setState(() { _rate = rate; _calculate(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.secondary.withValues(alpha: 0.18) : AppColors.darkCardElevated,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: isSelected ? AppColors.secondary : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
                ),
                child: Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: isSelected ? AppColors.secondary : AppColors.darkTextSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.xl),

        if (_result != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.darkBorder, width: 0.5),
            ),
            child: Column(
              children: [
                CalculatorResultRow(label: 'Base Amount', value: _currencyFmt.format(_result!.baseAmount)),
                CalculatorResultRow(label: 'GST (${_rate.toStringAsFixed(0)}%)', value: _currencyFmt.format(_result!.gstAmount), valueColor: AppColors.secondary),
                const Divider(color: AppColors.darkDivider, height: AppSpacing.lg),
                CalculatorResultRow(label: 'Total Amount', value: _currencyFmt.format(_result!.totalAmount), emphasized: true),
              ],
            ),
          ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected ? Colors.black87 : AppColors.darkTextTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
