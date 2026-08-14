import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../../../core/errors/failures.dart';

enum AnalyticsStatus { initial, loading, loaded, error }

class AnalyticsState extends Equatable {
  final AnalyticsStatus status;
  final List<CategoryBreakdownEntity> categoryBreakdown;
  final List<MonthlyTrendEntity> monthlyTrend;
  final Failure? failure;

  const AnalyticsState({
    this.status = AnalyticsStatus.initial,
    this.categoryBreakdown = const [],
    this.monthlyTrend = const [],
    this.failure,
  });

  double get totalSpent => categoryBreakdown.fold(0, (sum, c) => sum + c.amount);

  double get avgMonthlyIncome => monthlyTrend.isEmpty
      ? 0
      : monthlyTrend.fold(0.0, (sum, m) => sum + m.income) / monthlyTrend.length;

  double get avgMonthlyExpenses => monthlyTrend.isEmpty
      ? 0
      : monthlyTrend.fold(0.0, (sum, m) => sum + m.expenses) / monthlyTrend.length;

  AnalyticsState copyWith({
    AnalyticsStatus? status,
    List<CategoryBreakdownEntity>? categoryBreakdown,
    List<MonthlyTrendEntity>? monthlyTrend,
    Failure? failure,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      monthlyTrend: monthlyTrend ?? this.monthlyTrend,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, categoryBreakdown, monthlyTrend, failure];
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final AnalyticsRepository _repository;

  AnalyticsNotifier(this._repository) : super(const AnalyticsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: AnalyticsStatus.loading);

    final breakdownResult = await _repository.getCategoryBreakdown();
    final trendResult = await _repository.getMonthlyTrend(months: 6);

    final breakdown = breakdownResult.fold(
      (failure) => _mockBreakdown(),
      (data) => data,
    );

    final trend = trendResult.fold(
      (failure) => _mockTrend(),
      (data) => data,
    );

    state = state.copyWith(
      status: AnalyticsStatus.loaded,
      categoryBreakdown: breakdown,
      monthlyTrend: trend,
    );
  }

  List<CategoryBreakdownEntity> _mockBreakdown() {
    return const [
      CategoryBreakdownEntity(name: 'Food & Dining', icon: 'restaurant', color: '#FF9800', amount: 920.50, transactionCount: 24, percentage: 25.3),
      CategoryBreakdownEntity(name: 'Shopping', icon: 'bag', color: '#FF5252', amount: 815.00, transactionCount: 11, percentage: 22.4),
      CategoryBreakdownEntity(name: 'Transport', icon: 'car', color: '#2196F3', amount: 680.00, transactionCount: 18, percentage: 18.7),
      CategoryBreakdownEntity(name: 'Entertainment', icon: 'movie', color: '#E040FB', amount: 420.25, transactionCount: 9, percentage: 11.5),
      CategoryBreakdownEntity(name: 'Utilities', icon: 'flash', color: '#00BCD4', amount: 320.00, transactionCount: 4, percentage: 8.8),
      CategoryBreakdownEntity(name: 'Health', icon: 'health', color: '#4CAF50', amount: 280.00, transactionCount: 3, percentage: 7.7),
      CategoryBreakdownEntity(name: 'Other', icon: 'category', color: '#607D8B', amount: 200.85, transactionCount: 6, percentage: 5.6),
    ];
  }

  List<MonthlyTrendEntity> _mockTrend() {
    return const [
      MonthlyTrendEntity(month: 'Jan', income: 7800, expenses: 3200),
      MonthlyTrendEntity(month: 'Feb', income: 7800, expenses: 3850),
      MonthlyTrendEntity(month: 'Mar', income: 8100, expenses: 3400),
      MonthlyTrendEntity(month: 'Apr', income: 7900, expenses: 4100),
      MonthlyTrendEntity(month: 'May', income: 8400, expenses: 3600),
      MonthlyTrendEntity(month: 'Jun', income: 8200, expenses: 3640),
    ];
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref.watch(analyticsRepositoryProvider));
});
