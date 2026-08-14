import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../expenses/domain/entities/expense_entity.dart';
import '../../income/domain/entities/income_entity.dart';
import '../../budget/domain/entities/budget_entity.dart';
import 'csv_exporter.dart';

enum ReportPeriod { thisMonth, lastMonth, last3Months, thisYear, allTime }

extension ReportPeriodX on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.thisMonth => 'This Month',
    ReportPeriod.lastMonth => 'Last Month',
    ReportPeriod.last3Months => 'Last 3 Months',
    ReportPeriod.thisYear => 'This Year',
    ReportPeriod.allTime => 'All Time',
  };

  DateTime? get startDate {
    final now = DateTime.now();
    return switch (this) {
      ReportPeriod.thisMonth => DateTime(now.year, now.month, 1),
      ReportPeriod.lastMonth => DateTime(now.year, now.month - 1, 1),
      ReportPeriod.last3Months => DateTime(now.year, now.month - 3, 1),
      ReportPeriod.thisYear => DateTime(now.year, 1, 1),
      ReportPeriod.allTime => null,
    };
  }

  DateTime? get endDate {
    final now = DateTime.now();
    if (this == ReportPeriod.lastMonth) {
      return DateTime(now.year, now.month, 0, 23, 59, 59);
    }
    return null;
  }
}

/// Generates real, valid CSV and PDF files from the user's actual financial
/// data — no placeholder content. Files are written to the app's documents
/// directory and returned as a File ready for sharing via share_plus.
class ReportGeneratorService {
  static final _dateFmt = DateFormat('MMM d, yyyy');
  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // ─── CSV Export ─────────────────────────────────────────────────────────

  Future<File> generateTransactionsCsv({
    required List<ExpenseEntity> expenses,
    required List<IncomeEntity> incomes,
  }) async {
    final headers = ['Date', 'Type', 'Title', 'Category', 'Amount', 'Payment Method', 'Notes'];

    // Build (date, row) pairs so we can sort chronologically on the real
    // DateTime rather than round-tripping through a formatted string.
    final entries = <(DateTime date, List<Object?> row)>[];

    for (final e in expenses) {
      entries.add((
        e.date,
        [
          _dateFmt.format(e.date), 'Expense', e.title, e.category?.name ?? 'Uncategorized',
          '-${e.amount.toStringAsFixed(2)}', e.paymentMethod ?? '', e.notes ?? '',
        ],
      ),);
    }
    for (final i in incomes) {
      entries.add((
        i.date,
        [
          _dateFmt.format(i.date), 'Income', i.title, i.category?.name ?? 'Uncategorized',
          '+${i.amount.toStringAsFixed(2)}', i.source ?? '', i.notes ?? '',
        ],
      ),);
    }

    entries.sort((a, b) => a.$1.compareTo(b.$1));
    final rows = entries.map((e) => e.$2).toList();

    final csv = CsvExporter.build(headers, rows);
    return _writeToFile('fintrack_transactions_${_timestamp()}.csv', csv);
  }

  // ─── PDF Summary Report ──────────────────────────────────────────────────

  Future<File> generateSummaryPdf({
    required ReportPeriod period,
    required double totalIncome,
    required double totalExpenses,
    required List<BudgetEntity> budgets,
    required List<ExpenseEntity> topExpenses,
  }) async {
    final doc = pw.Document();
    final net = totalIncome - totalExpenses;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(period),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildSummarySection(totalIncome, totalExpenses, net),
          pw.SizedBox(height: 24),
          if (budgets.isNotEmpty) ...[
            _buildSectionTitle('Budget Performance'),
            pw.SizedBox(height: 8),
            _buildBudgetTable(budgets),
            pw.SizedBox(height: 24),
          ],
          if (topExpenses.isNotEmpty) ...[
            _buildSectionTitle('Top Expenses'),
            pw.SizedBox(height: 8),
            _buildExpensesTable(topExpenses),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return _writeBytesToFile('fintrack_report_${_timestamp()}.pdf', bytes);
  }

  pw.Widget _buildPdfHeader(ReportPeriod period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('FinTrack Pro', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6C63FF'))),
            pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Financial Summary Report — ${period.label}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Divider(color: PdfColors.grey300, thickness: 1, height: 20),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(title, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold));
  }

  pw.Widget _buildSummarySection(double income, double expenses, double net) {
    return pw.Row(
      children: [
        _summaryCard('Income', _currencyFmt.format(income), PdfColor.fromHex('#00D4A8')),
        pw.SizedBox(width: 12),
        _summaryCard('Expenses', _currencyFmt.format(expenses), PdfColor.fromHex('#FF5252')),
        pw.SizedBox(width: 12),
        _summaryCard('Net', _currencyFmt.format(net), net >= 0 ? PdfColor.fromHex('#00D4A8') : PdfColor.fromHex('#FF5252')),
      ],
    );
  }

  pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildBudgetTable(List<BudgetEntity> budgets) {
    return pw.TableHelper.fromTextArray(
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#6C63FF')),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
      headers: ['Category', 'Budgeted', 'Spent', '% Used'],
      data: budgets.map((b) => [
        b.name,
        _currencyFmt.format(b.amount),
        _currencyFmt.format(b.spent),
        '${b.percentageUsed.toStringAsFixed(0)}%',
      ],).toList(),
    );
  }

  pw.Widget _buildExpensesTable(List<ExpenseEntity> expenses) {
    return pw.TableHelper.fromTextArray(
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#6C63FF')),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight},
      headers: ['Date', 'Description', 'Amount'],
      data: expenses.map((e) => [
        _dateFmt.format(e.date),
        e.title,
        _currencyFmt.format(e.amount),
      ],).toList(),
    );
  }

  // ─── File I/O ─────────────────────────────────────────────────────────────

  Future<File> _writeToFile(String filename, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(content);
  }

  Future<File> _writeBytesToFile(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsBytes(bytes);
  }

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
}
