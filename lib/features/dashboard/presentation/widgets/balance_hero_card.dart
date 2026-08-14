import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';

class BalanceHeroCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  const BalanceHeroCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.period,
    required this.onPeriodChanged,
  });

  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _compactFmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF0E0E24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decoration circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                _PeriodSelector(
                  selected: period,
                  onChanged: onPeriodChanged,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Balance label
                Text(
                  'Total Balance',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.darkTextTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Balance amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '\$',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.darkTextSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _formatBalance(balance),
                        style: AppTypography.amountHero.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                const Divider(
                  color: AppColors.darkDivider,
                  thickness: 0.5,
                  height: 1,
                ),
                const SizedBox(height: AppSpacing.base),

                // Income / Expenses row
                Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        label: 'Income',
                        amount: income,
                        icon: Icons.arrow_downward_rounded,
                        color: AppColors.income,
                      ),
                    ),
                    Container(
                      width: 0.5,
                      height: 40,
                      color: AppColors.darkDivider,
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Expenses',
                        amount: expenses,
                        icon: Icons.arrow_upward_rounded,
                        color: AppColors.expense,
                        alignment: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(double amount) {
    if (amount >= 1000000) return _compactFmt.format(amount).replaceFirst('\$', '');
    final formatted = _currencyFmt.format(amount);
    return formatted.replaceFirst('\$', '');
  }
}

// ─── Period Selector ─────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  static const periods = ['week', 'month', 'year'];

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.darkBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((p) {
          final isSelected = p == selected;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                _capitalize(p),
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.darkTextTertiary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}

// ─── Stat Column ─────────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final CrossAxisAlignment alignment;

  const _StatColumn({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.alignment = CrossAxisAlignment.start,
  });

  static final _fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignment == CrossAxisAlignment.start ? 0 : AppSpacing.base,
        right: alignment == CrossAxisAlignment.end ? 0 : AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: alignment == CrossAxisAlignment.end
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 11, color: color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _fmt.format(amount),
            style: AppTypography.amountSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
