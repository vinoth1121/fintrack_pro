import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:equatable/equatable.dart';
import '../../domain/report_generator_service.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../income/presentation/providers/income_provider.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../../core/network/dio_client.dart';

enum ExportStatus { idle, generating, success, error }

class ReportsState extends Equatable {
  final ReportPeriod selectedPeriod;
  final ExportStatus exportStatus;
  final String? errorMessage;

  const ReportsState({
    this.selectedPeriod = ReportPeriod.thisMonth,
    this.exportStatus = ExportStatus.idle,
    this.errorMessage,
  });

  ReportsState copyWith({
    ReportPeriod? selectedPeriod,
    ExportStatus? exportStatus,
    String? errorMessage,
  }) {
    return ReportsState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      exportStatus: exportStatus ?? this.exportStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [selectedPeriod, exportStatus, errorMessage];
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  final Ref _ref;
  final _generator = ReportGeneratorService();

  ReportsNotifier(this._ref) : super(const ReportsState());

  void setPeriod(ReportPeriod period) {
    state = state.copyWith(selectedPeriod: period);
  }

  /// Filters the already-loaded in-memory expense/income lists to the
  /// selected period. We deliberately reuse the existing providers' data
  /// rather than issuing new network calls — the data is already local
  /// and this keeps report generation instant.
  DateTime? get _periodStart => state.selectedPeriod.startDate;
  DateTime? get _periodEnd => state.selectedPeriod.endDate;

  bool _inPeriod(DateTime date) {
    if (_periodStart != null && date.isBefore(_periodStart!)) return false;
    if (_periodEnd != null && date.isAfter(_periodEnd!)) return false;
    return true;
  }

  Future<void> exportTransactionsCsv() async {
    state = state.copyWith(exportStatus: ExportStatus.generating, errorMessage: null);
    try {
      final expenses = _ref.read(expenseListProvider).expenses.where((e) => _inPeriod(e.date)).toList();
      final incomes = _ref.read(incomeListProvider).incomes.where((i) => _inPeriod(i.date)).toList();

      final file = await _generator.generateTransactionsCsv(expenses: expenses, incomes: incomes);
      await Share.shareXFiles([XFile(file.path)], subject: 'FinTrack Pro Transactions Export');
      await _logExport('CSV', 'Transactions Export');

      state = state.copyWith(exportStatus: ExportStatus.success);
    } catch (e) {
      state = state.copyWith(exportStatus: ExportStatus.error, errorMessage: 'Failed to generate CSV export.');
    }
  }

  Future<void> exportSummaryPdf() async {
    state = state.copyWith(exportStatus: ExportStatus.generating, errorMessage: null);
    try {
      final expenses = _ref.read(expenseListProvider).expenses.where((e) => _inPeriod(e.date)).toList();
      final incomes = _ref.read(incomeListProvider).incomes.where((i) => _inPeriod(i.date)).toList();
      final budgets = _ref.read(budgetListProvider).budgets;

      final totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amount);
      final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

      final topExpenses = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));

      final file = await _generator.generateSummaryPdf(
        period: state.selectedPeriod,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        budgets: budgets,
        topExpenses: topExpenses.take(10).toList(),
      );
      await Share.shareXFiles([XFile(file.path)], subject: 'FinTrack Pro Financial Summary');
      await _logExport('PDF', 'Financial Summary Report');

      state = state.copyWith(exportStatus: ExportStatus.success);
    } catch (e) {
      state = state.copyWith(exportStatus: ExportStatus.error, errorMessage: 'Failed to generate PDF report.');
    }
  }

  /// Best-effort audit log to the backend Report table. Failure here should
  /// never block the user's export — the file was already generated and
  /// shared successfully, which is the part that matters to them.
  Future<void> _logExport(String type, String title) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/reports/generate', data: {
        'type': type == 'CSV' ? 'CUSTOM' : 'MONTHLY_SUMMARY',
        'title': title,
        'parameters': {'period': state.selectedPeriod.name, 'format': type},
      },);
    } catch (_) {
      // Silent — export already succeeded from the user's perspective.
    }
  }
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier(ref);
});
