import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../../../core/errors/failures.dart';

// ─── State ───────────────────────────────────────────────────────────────────

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final DashboardSummaryEntity? summary;
  final Failure? failure;
  final String selectedPeriod; // 'week', 'month', 'year'

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.failure,
    this.selectedPeriod = 'month',
  });

  bool get isLoading => status == DashboardStatus.loading;
  bool get hasData => status == DashboardStatus.loaded && summary != null;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummaryEntity? summary,
    Failure? failure,
    String? selectedPeriod,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      failure: failure,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    );
  }

  @override
  List<Object?> get props => [status, summary, failure, selectedPeriod];
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: DashboardStatus.loading);
    // Simulate network delay during development
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: replace with real repository call
    state = state.copyWith(
      status: DashboardStatus.loaded,
      summary: _mockSummary(),
    );
  }

  Future<void> refresh() => load();

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    load();
  }

  DashboardSummaryEntity _mockSummary() {
    return DashboardSummaryEntity(
      totalBalance: 24580.50,
      totalIncome: 8200.00,
      totalExpenses: 3640.75,
      savingsRate: 55.6,
      budgetUsedPercent: 72.4,
      activeSubscriptions: 7,
      subscriptionsCost: 84.99,
      financialHealth: const FinancialHealthEntity(
        score: 82,
        grade: 'B+',
        insight: 'You are saving well this month. Consider investing your surplus.',
        tips: [
          'You have \$4559 in surplus this month.',
          'Your dining expenses increased 18% vs last month.',
          '3 subscriptions unused in 30+ days.',
        ],
      ),
      weeklySpending: const [320, 480, 290, 610, 425, 380, 510],
      recentTransactions: [
        RecentTransactionEntity(
          id: '1', title: 'Grocery Store', category: 'Food',
          amount: 86.40, isExpense: true,
          date: DateTime.now().subtract(const Duration(hours: 2)),
          color: '#FF9800', icon: 'cart',
        ),
        RecentTransactionEntity(
          id: '2', title: 'Monthly Salary', category: 'Income',
          amount: 8200.00, isExpense: false,
          date: DateTime.now().subtract(const Duration(days: 1)),
          color: '#00D4A8', icon: 'work',
        ),
        RecentTransactionEntity(
          id: '3', title: 'Netflix', category: 'Entertainment',
          amount: 15.99, isExpense: true,
          date: DateTime.now().subtract(const Duration(days: 2)),
          color: '#E040FB', icon: 'tv',
        ),
        RecentTransactionEntity(
          id: '4', title: 'Uber', category: 'Transport',
          amount: 22.50, isExpense: true,
          date: DateTime.now().subtract(const Duration(days: 2)),
          color: '#2196F3', icon: 'car',
        ),
        RecentTransactionEntity(
          id: '5', title: 'Freelance Project', category: 'Income',
          amount: 1200.00, isExpense: false,
          date: DateTime.now().subtract(const Duration(days: 3)),
          color: '#00D4A8', icon: 'code',
        ),
      ],
      topCategories: const [
        SpendingCategoryEntity(
          name: 'Food & Dining', amount: 920.50, percentage: 25.3,
          color: '#FF9800', icon: 'restaurant',
        ),
        SpendingCategoryEntity(
          name: 'Transport', amount: 680.00, percentage: 18.7,
          color: '#2196F3', icon: 'car',
        ),
        SpendingCategoryEntity(
          name: 'Entertainment', amount: 420.25, percentage: 11.5,
          color: '#E040FB', icon: 'movie',
        ),
        SpendingCategoryEntity(
          name: 'Shopping', amount: 815.00, percentage: 22.4,
          color: '#FF5252', icon: 'bag',
        ),
        SpendingCategoryEntity(
          name: 'Utilities', amount: 320.00, percentage: 8.8,
          color: '#00BCD4', icon: 'flash',
        ),
      ],
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
