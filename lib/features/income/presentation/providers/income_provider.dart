import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/income_entity.dart';
import '../../data/repositories/income_repository.dart';
import '../../data/models/income_model.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../../core/errors/failures.dart';

// ─── List State ──────────────────────────────────────────────────────────────

enum IncomeListStatus { initial, loading, loaded, error }

class IncomeListState extends Equatable {
  final IncomeListStatus status;
  final List<IncomeEntity> incomes;
  final Failure? failure;

  const IncomeListState({
    this.status = IncomeListStatus.initial,
    this.incomes = const [],
    this.failure,
  });

  double get totalAmount => incomes.fold(0, (sum, i) => sum + i.amount);

  double get monthlyRecurring =>
      incomes.where((i) => i.isRecurring).fold(0, (sum, i) => sum + i.amount);

  IncomeListState copyWith({
    IncomeListStatus? status,
    List<IncomeEntity>? incomes,
    Failure? failure,
  }) {
    return IncomeListState(
      status: status ?? this.status,
      incomes: incomes ?? this.incomes,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, incomes, failure];
}

class IncomeListNotifier extends StateNotifier<IncomeListState> {
  final IncomeRepository _repository;

  IncomeListNotifier(this._repository) : super(const IncomeListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: IncomeListStatus.loading);
    final result = await _repository.getIncome();

    result.fold(
      (failure) => state = state.copyWith(
        status: IncomeListStatus.loaded,
        incomes: _mockIncome(),
      ),
      (paginated) => state = state.copyWith(
        status: IncomeListStatus.loaded,
        incomes: paginated.items.map((e) => e.toEntity()).toList(),
      ),
    );
  }

  Future<void> deleteIncome(String id) async {
    final result = await _repository.deleteIncome(id);
    result.fold(
      (failure) {},
      (_) => state = state.copyWith(
        incomes: state.incomes.where((i) => i.id != id).toList(),
      ),
    );
  }

  List<IncomeEntity> _mockIncome() {
    final now = DateTime.now();
    return [
      IncomeEntity(
        id: '1', title: 'Monthly Salary', amount: 8200.00,
        date: now.subtract(const Duration(days: 1)),
        category: DefaultCategories.income[0], createdAt: now,
        isRecurring: true, source: 'Acme Corp',
      ),
      IncomeEntity(
        id: '2', title: 'Freelance Web Project', amount: 1200.00,
        date: now.subtract(const Duration(days: 3)),
        category: DefaultCategories.income[1], createdAt: now,
        source: 'Client - TechStart Inc',
      ),
      IncomeEntity(
        id: '3', title: 'Dividend Payout', amount: 340.50,
        date: now.subtract(const Duration(days: 7)),
        category: DefaultCategories.income[2], createdAt: now,
      ),
      IncomeEntity(
        id: '4', title: 'Birthday Gift', amount: 200.00,
        date: now.subtract(const Duration(days: 12)),
        category: DefaultCategories.income[3], createdAt: now,
      ),
    ];
  }
}

final incomeListProvider =
    StateNotifierProvider<IncomeListNotifier, IncomeListState>((ref) {
  return IncomeListNotifier(ref.watch(incomeRepositoryProvider));
});

// ─── Add Income Form ──────────────────────────────────────────────────────────

class AddIncomeFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final CategoryEntity? selectedCategory;
  final DateTime selectedDate;
  final bool isRecurring;

  AddIncomeFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.selectedCategory,
    DateTime? selectedDate,
    this.isRecurring = false,
  }) : selectedDate = selectedDate ?? DateTime.now();

  AddIncomeFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    CategoryEntity? selectedCategory,
    DateTime? selectedDate,
    bool? isRecurring,
    bool clearFailure = false,
  }) {
    return AddIncomeFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedDate: selectedDate ?? this.selectedDate,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, failure, isSuccess, selectedCategory, selectedDate, isRecurring,
  ];
}

class AddIncomeNotifier extends StateNotifier<AddIncomeFormState> {
  final IncomeRepository _repository;
  final Ref _ref;

  AddIncomeNotifier(this._repository, this._ref) : super(AddIncomeFormState());

  void selectCategory(CategoryEntity category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void toggleRecurring() {
    state = state.copyWith(isRecurring: !state.isRecurring);
  }

  Future<bool> submit({
    required String title,
    required double amount,
    String? notes,
    String? source,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final income = IncomeModel(
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
      source: source,
      createdAt: DateTime.now(),
    );

    final result = await _repository.createIncome(income);

    return result.fold(
      (failure) {
        _ref.read(incomeListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
      (_) {
        _ref.read(incomeListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final addIncomeProvider =
    StateNotifierProvider.autoDispose<AddIncomeNotifier, AddIncomeFormState>(
  (ref) => AddIncomeNotifier(ref.watch(incomeRepositoryProvider), ref),
);
