import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/expense_entity.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/models/expense_model.dart';
import '../../../../core/errors/failures.dart';

// ─── List State ──────────────────────────────────────────────────────────────

enum ExpenseListStatus { initial, loading, loaded, error, loadingMore }

class ExpenseListState extends Equatable {
  final ExpenseListStatus status;
  final List<ExpenseEntity> expenses;
  final Failure? failure;
  final int page;
  final bool hasMore;
  final String? categoryFilter;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  const ExpenseListState({
    this.status = ExpenseListStatus.initial,
    this.expenses = const [],
    this.failure,
    this.page = 1,
    this.hasMore = true,
    this.categoryFilter,
    this.searchQuery = '',
    this.startDate,
    this.endDate,
  });

  double get totalAmount => expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, List<ExpenseEntity>> get groupedByDate {
    final map = <String, List<ExpenseEntity>>{};
    for (final e in expenses) {
      final key = _dateKey(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    if (now.difference(target).inDays < 7) {
      return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7];
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  ExpenseListState copyWith({
    ExpenseListStatus? status,
    List<ExpenseEntity>? expenses,
    Failure? failure,
    int? page,
    bool? hasMore,
    String? categoryFilter,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool clearCategoryFilter = false,
  }) {
    return ExpenseListState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      failure: failure,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  List<Object?> get props => [
    status, expenses, failure, page, hasMore,
    categoryFilter, searchQuery, startDate, endDate,
  ];
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ExpenseListNotifier extends StateNotifier<ExpenseListState> {
  final ExpenseRepository _repository;

  ExpenseListNotifier(this._repository) : super(const ExpenseListState()) {
    load();
  }

  Future<void> load({bool reset = true}) async {
    if (reset) {
      state = state.copyWith(status: ExpenseListStatus.loading, page: 1);
    }

    final result = await _repository.getExpenses(
      page: 1,
      categoryId: state.categoryFilter,
      startDate: state.startDate,
      endDate: state.endDate,
      search: state.searchQuery,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          status: ExpenseListStatus.error,
          failure: failure,
        );
      },
      (paginated) {
        state = state.copyWith(
          status: ExpenseListStatus.loaded,
          expenses: paginated.items.map((e) => e.toEntity()).toList(),
          page: paginated.page,
          hasMore: paginated.page < paginated.totalPages,
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.status == ExpenseListStatus.loadingMore) return;
    state = state.copyWith(status: ExpenseListStatus.loadingMore);

    final result = await _repository.getExpenses(
      page: state.page + 1,
      categoryId: state.categoryFilter,
      startDate: state.startDate,
      endDate: state.endDate,
      search: state.searchQuery,
    );

    result.fold(
      (failure) => state = state.copyWith(status: ExpenseListStatus.loaded),
      (paginated) => state = state.copyWith(
        status: ExpenseListStatus.loaded,
        expenses: [...state.expenses, ...paginated.items.map((e) => e.toEntity())],
        page: paginated.page,
        hasMore: paginated.page < paginated.totalPages,
      ),
    );
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    load();
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(
      categoryFilter: categoryId,
      clearCategoryFilter: categoryId == null,
    );
    load();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
    load();
  }

  Future<void> deleteExpense(String id) async {
    final result = await _repository.deleteExpense(id);
    result.fold(
      (failure) {},
      (_) {
        state = state.copyWith(
          expenses: state.expenses.where((e) => e.id != id).toList(),
        );
      },
    );
  }

}

final expenseListProvider =
    StateNotifierProvider<ExpenseListNotifier, ExpenseListState>((ref) {
  return ExpenseListNotifier(ref.watch(expenseRepositoryProvider));
});

// ─── Add Expense Form Provider ───────────────────────────────────────────────

class AddExpenseFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final CategoryEntity? selectedCategory;
  final DateTime selectedDate;
  final String? selectedPaymentMethod;
  final bool isRecurring;
  final String? receiptUrl;

  AddExpenseFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.selectedCategory,
    DateTime? selectedDate,
    this.selectedPaymentMethod,
    this.isRecurring = false,
    this.receiptUrl,
  }) : selectedDate = selectedDate ?? DateTime.now();

  AddExpenseFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    CategoryEntity? selectedCategory,
    DateTime? selectedDate,
    String? selectedPaymentMethod,
    bool? isRecurring,
    String? receiptUrl,
    bool clearFailure = false,
  }) {
    return AddExpenseFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, failure, isSuccess, selectedCategory, selectedDate,
    selectedPaymentMethod, isRecurring, receiptUrl,
  ];
}

class AddExpenseNotifier extends StateNotifier<AddExpenseFormState> {
  final ExpenseRepository _repository;
  final Ref _ref;

  AddExpenseNotifier(this._repository, this._ref)
      : super(AddExpenseFormState(selectedDate: DateTime.now()));

  void selectCategory(CategoryEntity category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void selectPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void toggleRecurring() {
    state = state.copyWith(isRecurring: !state.isRecurring);
  }

  Future<bool> submit({
    required String title,
    required double amount,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final expense = ExpenseModel(
      id: '',
      title: title,
      amount: amount,
      date: state.selectedDate,
      category: state.selectedCategory != null
          ? CategoryModel(
              id: state.selectedCategory!.id,
              name: state.selectedCategory!.name,
              icon: state.selectedCategory!.icon,
              color: state.selectedCategory!.color,
            )
          : null,
      notes: notes,
      isRecurring: state.isRecurring,
      paymentMethod: state.selectedPaymentMethod,
      createdAt: DateTime.now(),
    );

    final result = await _repository.createExpense(expense);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
        return false;
      },
      (_) {
        _ref.read(expenseListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final addExpenseProvider =
    StateNotifierProvider.autoDispose<AddExpenseNotifier, AddExpenseFormState>(
  (ref) => AddExpenseNotifier(ref.watch(expenseRepositoryProvider), ref),
);
