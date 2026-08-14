import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/report_generator_service.dart';
import '../providers/reports_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../income/presentation/providers/income_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsProvider);
    final isGenerating = state.exportStatus == ExportStatus.generating;

    ref.listen(reportsProvider, (previous, next) {
      if (next.exportStatus == ExportStatus.error && next.errorMessage != null) {
        AppSnackbar.error(context, next.errorMessage!);
      }
    });

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
        title: Text('Reports & Export', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // ── Period Selector ────────────────────────────────────────────────
          Text('Report Period', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: ReportPeriod.values.map((period) {
              final isSelected = state.selectedPeriod == period;
              return GestureDetector(
                onTap: () => ref.read(reportsProvider.notifier).setPeriod(period),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
                  ),
                  child: Text(
                    period.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Preview Summary ────────────────────────────────────────────────
          _PeriodPreviewCard(period: state.selectedPeriod),

          const SizedBox(height: AppSpacing.xl),

          Text('Export Options', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),

          // ── PDF Summary Export ─────────────────────────────────────────────
          _ExportCard(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: const Color(0xFFFF5252),
            title: 'Financial Summary (PDF)',
            subtitle: 'Income, expenses, budget performance & top transactions',
            isLoading: isGenerating,
            onTap: () => ref.read(reportsProvider.notifier).exportSummaryPdf(),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── CSV Transactions Export ────────────────────────────────────────
          _ExportCard(
            icon: Icons.table_chart_rounded,
            iconColor: AppColors.income,
            title: 'All Transactions (CSV)',
            subtitle: 'Full transaction list — compatible with Excel & Sheets',
            isLoading: isGenerating,
            onTap: () => ref.read(reportsProvider.notifier).exportTransactionsCsv(),
          ),

          const SizedBox(height: AppSpacing.xl),

          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Exports are generated from your real transaction data and can be shared or saved directly from the share sheet.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Preview Card ──────────────────────────────────────────────────────

class _PeriodPreviewCard extends ConsumerWidget {
  final ReportPeriod period;
  const _PeriodPreviewCard({required this.period});

  bool _inPeriod(DateTime date) {
    final start = period.startDate;
    final end = period.endDate;
    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider).expenses.where((e) => _inPeriod(e.date)).toList();
    final incomes = ref.watch(incomeListProvider).incomes.where((i) => _inPeriod(i.date)).toList();

    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${expenses.length + incomes.length}', style: AppTypography.titleLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800)),
                Text('Transactions', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
              ],
            ),
          ),
          Container(width: 0.5, height: 36, color: AppColors.darkDivider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\$${totalIncome.toStringAsFixed(0)}', style: AppTypography.titleLarge.copyWith(color: AppColors.income, fontWeight: FontWeight.w800)),
                  Text('Income', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                ],
              ),
            ),
          ),
          Container(width: 0.5, height: 36, color: AppColors.darkDivider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('\$${totalExpenses.toStringAsFixed(0)}', style: AppTypography.titleLarge.copyWith(color: AppColors.expense, fontWeight: FontWeight.w800)),
                  Text('Expenses', style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export Card ──────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ExportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.ios_share_rounded, color: AppColors.darkTextTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
