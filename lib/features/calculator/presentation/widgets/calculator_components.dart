import 'package:flutter/material.dart';
import '../../../../core/constants/app_tokens.dart';

/// Reusable numeric keypad button grid used by the Basic Calculator.
class CalculatorKeypad extends StatelessWidget {
  final void Function(String key) onKeyTap;

  const CalculatorKeypad({super.key, required this.onKeyTap});

  static const _rows = [
    ['C', '±', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '+'],
    ['0', '.', '⌫', '='],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: _KeypadButton(label: key, onTap: () => onKeyTap(key)),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  bool get _isOperator => ['÷', '×', '-', '+', '='].contains(label);
  bool get _isFunction => ['C', '±', '%', '⌫'].contains(label);

  @override
  Widget build(BuildContext context) {
    final bgColor = _isOperator
        ? AppColors.primary
        : _isFunction
            ? AppColors.darkCardElevated
            : AppColors.darkCard;
    final textColor = _isOperator
        ? Colors.white
        : _isFunction
            ? AppColors.primary
            : AppColors.darkTextPrimary;

    return AspectRatio(
      aspectRatio: 1.3,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.base),
          child: Center(
            child: Text(
              label,
              style: AppTypography.headlineSmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large expression + result display shared by all calculator modes.
class CalculatorDisplay extends StatelessWidget {
  final String expression;
  final String result;
  final Color? accentColor;

  const CalculatorDisplay({
    super.key,
    required this.expression,
    required this.result,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (expression.isNotEmpty)
            Text(
              expression,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              result,
              style: AppTypography.amountHero.copyWith(
                color: accentColor ?? AppColors.darkTextPrimary,
                fontSize: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled input row used by EMI/GST/Savings calculators (non-keypad forms).
class CalculatorInputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String>? onChanged;

  const CalculatorInputRow({
    super.key,
    required this.label,
    required this.controller,
    required this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: onChanged,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixText: suffix,
                suffixStyle: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result summary row used in EMI/GST/Savings result cards.
class CalculatorResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  const CalculatorResultRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
          Text(
            value,
            style: (emphasized ? AppTypography.titleMedium : AppTypography.bodyMedium).copyWith(
              color: valueColor ?? AppColors.darkTextPrimary,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
