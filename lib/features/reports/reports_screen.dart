import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';
import 'domain/csv_exporter.dart';

const _dateRanges = <_DateRange>[
  _DateRange('month', 'This month'),
  _DateRange('30', 'Last 30 days'),
  _DateRange('90', 'Last 90 days'),
  _DateRange('year', 'This year'),
];

class _DateRange {
  final String id;
  final String label;
  const _DateRange(this.id, this.label);
}

class _TrendChartPoint {
  final String month;
  final double income;
  final double expense;
  const _TrendChartPoint(this.month, this.income, this.expense);
}

/// Reports & Export screen — date range, stat tiles, 6-month trend chart,
/// spending-by-category list, income sources, and a printable summary.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ReportsView();
  }
}

class _ReportsView extends ConsumerStatefulWidget {
  const _ReportsView();
  @override
  ConsumerState<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<_ReportsView> {
  String _range = 'month';

  String _rangeLabel(String id, AppT t) {
    switch (id) {
      case 'month':
        return t.common.thisMonth;
      case 'year':
        return t.reports.thisYear;
      case '30':
        return t.tx.last30;
      case '90':
        return t.tx.last90;
      default:
        return id;
    }
  }

  List<Transaction> _rangedTx() {
    final state = ref.read(fintrackProvider);
    final now = DateTime.now();
    bool inRange(DateTime d) {
      switch (_range) {
        case 'month':
          return d.year == now.year && d.month == now.month;
        case 'year':
          return d.year == now.year;
        case '30':
          return d.isAfter(now.subtract(const Duration(days: 30)));
        case '90':
          return d.isAfter(now.subtract(const Duration(days: 90)));
        default:
          return true;
      }
    }

    return state.transactions.where((t) => inRange(t.date)).toList();
  }

  String _categoryName(String categoryId) {
    final state = ref.read(fintrackProvider);
    for (final c in state.categories) {
      if (c.id == categoryId) return c.name;
    }
    return categoryId;
  }

  Future<File> _writeTempFile(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _handleCSV() async {
    final t = ref.read(tProvider);
    final ranged = _rangedTx();
    if (ranged.isEmpty) {
      showAppToast(context, t.messages.noTxInRange, kind: ToastKind.error);
      return;
    }
    try {
      final csv = CsvExporter.build(
        ['Date', 'Type', 'Category', 'Amount', 'Account', 'Merchant', 'Note'],
        ranged.map((tx) => [
          DateFormat('yyyy-MM-dd').format(tx.date),
          tx.type.name,
          _categoryName(tx.categoryId),
          tx.amount,
          tx.account,
          tx.merchant ?? '',
          tx.note ?? '',
        ],).toList(),
      );
      final file = await _writeTempFile(
        'fintrack_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
        csv.codeUnits,
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'FinTrack Pro report (${ranged.length} transactions)');
      if (!mounted) return;
      showAppToast(
        context,
        t.messages.txExportedCsv.replaceAll('{count}', '${ranged.length}'),
        kind: ToastKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Export failed: $e', kind: ToastKind.error);
    }
  }

  Future<void> _handlePDF() async {
    final t = ref.read(tProvider);
    final ranged = _rangedTx();
    if (ranged.isEmpty) {
      showAppToast(context, t.messages.noTxInRange, kind: ToastKind.error);
      return;
    }
    try {
      final state = ref.read(fintrackProvider);
      final currency = state.profile.baseCurrency;
      final income = ranged.where((x) => x.type == TxType.income).fold<double>(0, (a, x) => a + x.amount);
      final expense = ranged.where((x) => x.type == TxType.expense).fold<double>(0, (a, x) => a + x.amount);

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, text: 'FinTrack Pro — Financial Report'),
            pw.Text('Generated ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now())}'),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Income: $currency ${income.toStringAsFixed(2)}'),
                pw.Text('Total Expenses: $currency ${expense.toStringAsFixed(2)}'),
                pw.Text('Net: $currency ${(income - expense).toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Type', 'Category', 'Amount', 'Note'],
              data: ranged.map((tx) => [
                DateFormat('yyyy-MM-dd').format(tx.date),
                tx.type.name,
                _categoryName(tx.categoryId),
                '$currency ${tx.amount.toStringAsFixed(2)}',
                tx.note ?? '',
              ],).toList(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      final file = await _writeTempFile(
        'fintrack_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
        await doc.save(),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'FinTrack Pro report (${ranged.length} transactions)');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'PDF export failed: $e', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final d = ref.watch(derivedProvider);
    final l = context.lumina;
    final currency = state.profile.baseCurrency;

    final trendData = d.trend
        .map((p) => _TrendChartPoint(p.month, p.income, p.expense))
        .toList();
    final topCategories = d.categoryBreakdown.take(6).toList();
    final incomeSources = _computeIncomeSources(state.transactions);
    final netSavings = d.totalIncome - d.totalExpenses;
    final savingsPct = (d.savingsRate * 100).round();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Header
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.reports.reportsExport,
                        style: AppTypography.display(context, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate financial summaries for any period',
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GhostButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      onPressed: _handlePDF,
                      child: Text(t.reports.exportPdf),
                    ),
                    GradientButton(
                      icon: const Icon(Icons.table_view_outlined, size: 16),
                      onPressed: _handleCSV,
                      child: Text(t.reports.exportCsv),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Range select
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.date_range_outlined, size: 18, color: AppColors.iris),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reporting period',
                    style: AppTypography.body(context, size: 13, weight: FontWeight.w500),
                  ),
                ),
                _RangeDropdown(
                  value: _range,
                  items: _dateRanges.map((r) => _DateRangeItem(r.id, _rangeLabel(r.id, t))).toList(),
                  onChanged: (v) => setState(() => _range = v),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Stat tiles
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth < 720;
              final tiles = <Widget>[
                StatTile(
                  label: t.analytics.totalIncome,
                  icon: const Icon(Icons.trending_up, size: 16),
                  accent: 'green',
                  value: AmountText(
                    value: d.totalIncome,
                    currency: currency,
                    size: 22,
                    weight: FontWeight.bold,
                    compact: true,
                  ),
                ),
                StatTile(
                  label: t.analytics.totalExpenses,
                  icon: const Icon(Icons.trending_down, size: 16),
                  accent: 'amber',
                  value: AmountText(
                    value: d.totalExpenses,
                    currency: currency,
                    size: 22,
                    weight: FontWeight.bold,
                    compact: true,
                  ),
                ),
                StatTile(
                  label: 'Net savings',
                  icon: const Icon(Icons.savings_outlined, size: 16),
                  accent: 'iris',
                  value: AmountText(
                    value: netSavings,
                    currency: currency,
                    size: 22,
                    weight: FontWeight.bold,
                    compact: true,
                  ),
                ),
                StatTile(
                  label: t.analytics.savingsRate,
                  icon: const Icon(Icons.percent, size: 16),
                  accent: 'cyan',
                  value: Text(
                    '$savingsPct%',
                    style: AppTypography.amount(context, size: 22, weight: FontWeight.bold),
                  ),
                ),
              ];
              final perRow = twoCol ? 2 : 4;
              return Column(
                children: [
                  for (var i = 0; i < tiles.length; i += perRow)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = i; j < i + perRow && j < tiles.length; j++) ...[
                            Expanded(child: tiles[j]),
                            if (j < i + perRow - 1 && j < tiles.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    )
                        .animate(delay: (100 + i * 30).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.05, end: 0, duration: 350.ms),
                ],
              );
            },
          ),

          const SizedBox(height: 4),

          // Income vs expenses trend chart
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: t.analytics.incomeVsExpenses,
                  subtitle: t.misc.sixMonthTrend,
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(color: AppColors.iris, label: t.common.income),
                      const SizedBox(width: 12),
                      _LegendDot(color: AppColors.cyan, label: t.common.expense),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: CustomPaint(
                    painter: _TrendChartPainter(
                      points: trendData,
                      incomeColor: AppColors.iris,
                      expenseColor: AppColors.cyan,
                      gridColor: l.border.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Spending by category + Income sources
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= 720;
              final left = GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Spending by category',
                      subtitle: 'This month · top 6',
                    ),
                    if (topCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: EmptyState(
                          icon: const Icon(Icons.trending_down, size: 18),
                          title: 'No spending yet',
                          description: t.misc.addExpensesToSeeBreakdown,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: topCategories.asMap().entries.map((e) {
                            final i = e.key;
                            final cat = e.value;
                            return _CategoryRow(
                              name: cat.name,
                              color: _hex(cat.color),
                              pct: cat.pct,
                              amount: cat.amount,
                              currency: currency,
                              delay: (300 + i * 40).ms,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 260.ms).slideY(begin: 0.05, end: 0);

              final right = GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: t.reports.incomeSources,
                      subtitle: 'Top merchants · all time',
                    ),
                    if (incomeSources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: EmptyState(
                          icon: const Icon(Icons.south_west, size: 18),
                          title: 'No income recorded',
                          description: t.misc.addIncomeToSeeSources,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: incomeSources.asMap().entries.map((e) {
                            final i = e.key;
                            final s = e.value;
                            return _IncomeSourceRow(
                              merchant: s.merchant,
                              total: s.total,
                              count: s.count,
                              maxTotal: incomeSources.first.total,
                              currency: currency,
                              delay: (320 + i * 40).ms,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 320.ms).slideY(begin: 0.05, end: 0);

              if (twoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right],
              );
            },
          ),

          const SizedBox(height: 16),

          // Printable summary card
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GradientPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.print_outlined, size: 12),
                                const SizedBox(width: 4),
                                Text(t.reports.summary),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t.reports.financialSummary,
                            style: AppTypography.display(context, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prepared for ${state.profile.name} · ${formatDate(DateTime.now(), style: 'long')}',
                            style: AppTypography.body(context, size: 12)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    GhostButton(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      onPressed: _handlePDF,
                      child: Text(t.reports.print),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth < 720;
                    final cells = <Widget>[
                      _SummaryCell(
                        label: t.profile.netWorth,
                        value: AmountText(
                          value: d.netBalance,
                          currency: currency,
                          size: 16,
                          weight: FontWeight.w600,
                          compact: true,
                        ),
                      ),
                      _SummaryCell(
                        label: t.analytics.totalIncome,
                        value: AmountText(
                          value: d.totalIncome,
                          currency: currency,
                          size: 16,
                          weight: FontWeight.w600,
                          compact: true,
                          color: AppColors.success,
                        ),
                      ),
                      _SummaryCell(
                        label: t.analytics.totalExpenses,
                        value: AmountText(
                          value: d.totalExpenses,
                          currency: currency,
                          size: 16,
                          weight: FontWeight.w600,
                          compact: true,
                          color: AppColors.error,
                        ),
                      ),
                      _SummaryCell(
                        label: t.analytics.savingsRate,
                        value: Text(
                          '$savingsPct%',
                          style: AppTypography.amount(context, size: 16, weight: FontWeight.w600)
                              .copyWith(color: AppColors.iris),
                        ),
                      ),
                    ];
                    return Column(
                      children: [
                        for (var i = 0; i < cells.length; i += (twoCol ? 2 : 4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var j = i; j < i + (twoCol ? 2 : 4) && j < cells.length; j++) ...[
                                  Expanded(child: cells[j]),
                                  if (j < i + (twoCol ? 2 : 4) - 1 && j < cells.length - 1)
                                    const SizedBox(width: 12),
                                ],
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: l.surface3.withValues(alpha: 0.3),
                    border: Border.all(color: l.border, width: 1),
                  ),
                  child: Text(
                    'Note: This is a demo summary for visualization only. Use the export buttons above to download a full report in PDF or CSV format.',
                    style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
        ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------ helpers ------------------------------ */

Color _hex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class _IncomeSource {
  final String merchant;
  final double total;
  final int count;
  const _IncomeSource(this.merchant, this.total, this.count);
}

List<_IncomeSource> _computeIncomeSources(List<Transaction> transactions) {
  final map = <String, _IncomeSource>{};
  for (final t in transactions) {
    if (t.type != TxType.income) continue;
    final m = t.merchant ?? 'Unknown';
    final cur = map[m] ?? _IncomeSource(m, 0, 0);
    map[m] = _IncomeSource(m, cur.total + t.amount, cur.count + 1);
  }
  final list = map.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  return list.take(6).toList();
}

/* ------------------------------ Range dropdown ------------------------------ */

class _DateRangeItem {
  final String id;
  final String label;
  const _DateRangeItem(this.id, this.label);
}

class _RangeDropdown extends StatelessWidget {
  final String value;
  final List<_DateRangeItem> items;
  final ValueChanged<String> onChanged;
  const _RangeDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final current = items.firstWhere((i) => i.id == value, orElse: () => items.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: l.surface3.withValues(alpha: 0.4),
        border: Border.all(color: l.border, width: 1),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: l.surface3.withValues(alpha: 0.98),
        onSelected: onChanged,
        itemBuilder: (_) => items
            .map((i) => PopupMenuItem(
                  value: i.id,
                  child: Text(i.label, style: AppTypography.label(context, size: 13)),
                ),)
            .toList(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: AppTypography.label(context, size: 13, weight: FontWeight.w500)
                  .copyWith(color: l.foreground),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: l.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Legend dot ------------------------------ */

class _TrendChartPainter extends CustomPainter {
  final List<_TrendChartPoint> points;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;

  const _TrendChartPainter({
    required this.points,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final maxValue = points.fold<double>(1, (prev, point) => math.max(prev, math.max(point.income, point.expense))) * 1.1;
    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;
    final barWidth = chartWidth / math.max(1, points.length * 3);

    for (var i = 0; i < 4; i++) {
      final y = 12 + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = 12 + (barWidth * 1.5 * i) + (barWidth * 0.3);
      final incomeHeight = (point.income / maxValue) * chartHeight;
      final expenseHeight = (point.expense / maxValue) * chartHeight;

      paint.color = incomeColor;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - 12 - incomeHeight, barWidth * 0.4, incomeHeight),
        paint,
      );

      paint.color = expenseColor;
      canvas.drawRect(
        Rect.fromLTWH(x + barWidth * 0.5, size.height - 12 - expenseHeight, barWidth * 0.4, expenseHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.incomeColor != incomeColor ||
        oldDelegate.expenseColor != expenseColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.label(context, size: 11).copyWith(color: l.mutedForeground),
        ),
      ],
    );
  }
}

/* ------------------------------ Category row ------------------------------ */

class _CategoryRow extends StatelessWidget {
  final String name;
  final Color color;
  final int pct;
  final double amount;
  final String currency;
  final Duration delay;
  const _CategoryRow({
    required this.name,
    required this.color,
    required this.pct,
    required this.amount,
    required this.currency,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ProgressRing(
            value: pct.toDouble(),
            size: 44,
            stroke: 5,
            color: color,
            child: Text(
              '$pct%',
              style: AppTypography.amount(context, size: 9, weight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.body(context, size: 13, weight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AmountText(
                      value: amount,
                      currency: currency,
                      size: 13,
                      weight: FontWeight.w500,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: l.surface3,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: delay)
        .slideX(begin: -0.04, end: 0, duration: 350.ms, delay: delay);
  }
}

/* ------------------------------ Income source row ------------------------------ */

class _IncomeSourceRow extends StatelessWidget {
  final String merchant;
  final double total;
  final int count;
  final double maxTotal;
  final String currency;
  final Duration delay;
  const _IncomeSourceRow({
    required this.merchant,
    required this.total,
    required this.count,
    required this.maxTotal,
    required this.currency,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final widthPct = maxTotal <= 0 ? 0.0 : (total / maxTotal).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.3),
                  AppColors.success.withValues(alpha: 0.05),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.south_west, size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant,
                        style: AppTypography.body(context, size: 13, weight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AmountText(
                      value: total,
                      currency: currency,
                      size: 13,
                      weight: FontWeight.w500,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: widthPct,
                    minHeight: 6,
                    backgroundColor: l.surface3,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${count}x',
            style: AppTypography.label(context, size: 10).copyWith(color: l.mutedForeground),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: delay)
        .slideX(begin: 0.04, end: 0, duration: 350.ms, delay: delay);
  }
}

/* ------------------------------ Summary cell ------------------------------ */

class _SummaryCell extends StatelessWidget {
  final String label;
  final Widget value;
  const _SummaryCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: l.surface3.withValues(alpha: 0.3),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.label(context, size: 10)
                .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: AppTypography.amount(context, size: 16, weight: FontWeight.w600),
            child: value,
          ),
        ],
      ),
    );
  }
}
