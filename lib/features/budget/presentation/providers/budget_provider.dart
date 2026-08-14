import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/budget_entity.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/models/budget_model.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../../core/errors/failures.dart';

// ─── List State ──────────────────────────────────────────────────────────────

enum BudgetListStatus { initial, loading, loaded, error }

class BudgetListState extends Equatable {
  final BudgetListStatus status;
  final List<BudgetEntity> budgets;
  final Failure? failure;

  const BudgetListState({
    this.status = BudgetListStatus.initial,
    this.budgets = const [],
    this.failure,
  });

  double get totalBudgeted => budgets.fold(0, (sum, b) => sum + b.amount);
  double get totalSpent => budgets.fold(0, (sum, b) => sum + b.spent);
  double get overallPercentage =>
      totalBudgeted > 0 ? (totalSpent / totalBudgeted * 100).clamp(0, 999) : 0;
  int get overBudgetCount => budgets.where((b) => b.isOverBudget).length;

  BudgetListState copyWith({
    BudgetListStatus? status,
    List<BudgetEntity>? budgets,
    Failure? failure,
  }) {
    return BudgetListState(
      status: status ?? this.status,
      budgets: budgets ?? this.budgets,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, budgets, failure];
}

class BudgetListNotifier extends StateNotifier<BudgetListState> {
  final BudgetRepository _repository;

  BudgetListNotifier(this._repository) : super(const BudgetListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: BudgetListStatus.loading);
    final result = await _repository.getBudgets();

    result.fold(
      (failure) => state = state.copyWith(
        status: BudgetListStatus.loaded,
        budgets: _mockBudgets(),
      ),
      (models) => state = state.copyWith(
        status: BudgetListStatus.loaded,
        budgets: models.map((m) => m.toEntity()).toList(),
      ),
    );
  }

  Future<void> deleteBudget(String id) async {
    final result = await _repository.deleteBudget(id);
    result.fold(
      (failure) {},
      (_) => state = state.copyWith(
        budgets: state.budgets.where((b) => b.id != id).toList(),
      ),
    );
  }

  List<BudgetEntity> _mockBudgets() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return [
      BudgetEntity(
        id: '1', name: 'Food & Dining', category: DefaultCategories.expense[0],
        amount: 600, spent: 482.50, startDate: startOfMonth, color: '#FF9800',
      ),
      BudgetEntity(
        id: '2', name: 'Transport', category: DefaultCategories.expense[1],
        amount: 300, spent: 215.00, startDate: startOfMonth, color: '#2196F3',
      ),
      BudgetEntity(
        id: '3', name: 'Shopping', category: DefaultCategories.expense[2],
        amount: 250, spent: 289.99, startDate: startOfMonth, color: '#FF5252',
      ),
      BudgetEntity(
        id: '4', name: 'Entertainment', category: DefaultCategories.expense[3],
        amount: 150, spent: 64.99, startDate: startOfMonth, color: '#E040FB',
      ),
      BudgetEntity(
        id: '5', name: 'Utilities', category: DefaultCategories.expense[4],
        amount: 200, spent: 178.30, startDate: startOfMonth, color: '#00BCD4',
      ),
    ];
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, BudgetListState>((ref) {
  return BudgetListNotifier(ref.watch(budgetRepositoryProvider));
});

// ─── Add Budget Form ──────────────────────────────────────────────────────────

class AddBudgetFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final CategoryEntity? selectedCategory;
  final BudgetPeriod period;
  final int alertAt;

  const AddBudgetFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.selectedCategory,
    this.period = BudgetPeriod.monthly,
    this.alertAt = 80,
  });

  AddBudgetFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    CategoryEntity? selectedCategory,
    BudgetPeriod? period,
    int? alertAt,
    bool clearFailure = false,
  }) {
    return AddBudgetFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      period: period ?? this.period,
      alertAt: alertAt ?? this.alertAt,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess, selectedCategory, period, alertAt];
}

class AddBudgetNotifier extends StateNotifier<AddBudgetFormState> {
  final BudgetRepository _repository;
  final Ref _ref;

  AddBudgetNotifier(this._repository, this._ref) : super(const AddBudgetFormState());

  void selectCategory(CategoryEntity category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectPeriod(BudgetPeriod period) {
    state = state.copyWith(period: period);
  }

  void setAlertThreshold(int value) {
    state = state.copyWith(alertAt: value);
  }

  Future<bool> submit({required String name, required double amount}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final budget = BudgetModel(
      id: '',
      name: name,
      category: state.selectedCategory != null
          ? CategoryModel(
              id: state.selectedCategory!.id,
              name: state.selectedCategory!.name,
              icon: state.selectedCategory!.icon,
              color: state.selectedCategory!.color,
            )
          : null,
      amount: amount,
      period: switch (state.period) {
        BudgetPeriod.weekly => 'WEEKLY',
        BudgetPeriod.yearly => 'YEARLY',
        BudgetPeriod.monthly => 'MONTHLY',
      },
      startDate: DateTime.now(),
      alertAt: state.alertAt,
      color: state.selectedCategory?.color,
    );

    final result = await _repository.createBudget(budget);

    return result.fold(
      (failure) {
        _ref.read(budgetListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
      (_) {
        _ref.read(budgetListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final addBudgetProvider =
    StateNotifierProvider.autoDispose<AddBudgetNotifier, AddBudgetFormState>(
  (ref) => AddBudgetNotifier(ref.watch(budgetRepositoryProvider), ref),
);
