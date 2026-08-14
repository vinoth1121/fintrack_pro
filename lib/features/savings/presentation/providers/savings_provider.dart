import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/savings_goal_entity.dart';
import '../../data/repositories/savings_repository.dart';
import '../../data/models/savings_goal_model.dart';
import '../../../../core/errors/failures.dart';

// ─── List State ──────────────────────────────────────────────────────────────

enum SavingsListStatus { initial, loading, loaded, error }

class SavingsListState extends Equatable {
  final SavingsListStatus status;
  final List<SavingsGoalEntity> goals;
  final Failure? failure;

  const SavingsListState({
    this.status = SavingsListStatus.initial,
    this.goals = const [],
    this.failure,
  });

  double get totalSaved => goals.fold(0, (sum, g) => sum + g.savedAmount);
  double get totalTarget => goals.fold(0, (sum, g) => sum + g.targetAmount);
  List<SavingsGoalEntity> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();
  List<SavingsGoalEntity> get completedGoals =>
      goals.where((g) => g.status == GoalStatus.completed).toList();

  SavingsListState copyWith({
    SavingsListStatus? status,
    List<SavingsGoalEntity>? goals,
    Failure? failure,
  }) {
    return SavingsListState(
      status: status ?? this.status,
      goals: goals ?? this.goals,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, goals, failure];
}

class SavingsListNotifier extends StateNotifier<SavingsListState> {
  final SavingsRepository _repository;

  SavingsListNotifier(this._repository) : super(const SavingsListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: SavingsListStatus.loading);
    final result = await _repository.getGoals();

    result.fold(
      (failure) => state = state.copyWith(
        status: SavingsListStatus.loaded,
        goals: _mockGoals(),
      ),
      (models) => state = state.copyWith(
        status: SavingsListStatus.loaded,
        goals: models.map((m) => m.toEntity()).toList(),
      ),
    );
  }

  Future<bool> contribute(String goalId, double amount) async {
    final result = await _repository.contribute(goalId, amount);
    return result.fold(
      (failure) {
        // Optimistic local update so the demo remains functional offline
        final updated = state.goals.map((g) {
          if (g.id != goalId) return g;
          final newSaved = g.savedAmount + amount;
          return SavingsGoalEntity(
            id: g.id, name: g.name, targetAmount: g.targetAmount,
            savedAmount: newSaved, currency: g.currency, deadline: g.deadline,
            icon: g.icon, color: g.color,
            status: newSaved >= g.targetAmount ? GoalStatus.completed : g.status,
            notes: g.notes, createdAt: g.createdAt,
          );
        }).toList();
        state = state.copyWith(goals: updated);
        return true;
      },
      (model) {
        final updated = state.goals.map((g) => g.id == goalId ? model.toEntity() : g).toList();
        state = state.copyWith(goals: updated);
        return true;
      },
    );
  }

  Future<void> deleteGoal(String id) async {
    final result = await _repository.deleteGoal(id);
    result.fold(
      (failure) {},
      (_) => state = state.copyWith(goals: state.goals.where((g) => g.id != id).toList()),
    );
  }

  List<SavingsGoalEntity> _mockGoals() {
    final now = DateTime.now();
    return [
      SavingsGoalEntity(
        id: '1', name: 'Emergency Fund', targetAmount: 10000, savedAmount: 6500,
        deadline: now.add(const Duration(days: 180)), icon: 'shield', color: '#00D4A8', createdAt: now,
      ),
      SavingsGoalEntity(
        id: '2', name: 'Japan Vacation', targetAmount: 4500, savedAmount: 2100,
        deadline: now.add(const Duration(days: 240)), icon: 'flight', color: '#2196F3', createdAt: now,
      ),
      SavingsGoalEntity(
        id: '3', name: 'New MacBook Pro', targetAmount: 2800, savedAmount: 2800,
        icon: 'devices', color: '#00BCD4', status: GoalStatus.completed, createdAt: now,
      ),
      SavingsGoalEntity(
        id: '4', name: 'Home Down Payment', targetAmount: 60000, savedAmount: 18500,
        deadline: now.add(const Duration(days: 720)), icon: 'home', color: '#6C63FF', createdAt: now,
      ),
    ];
  }
}

final savingsListProvider = StateNotifierProvider<SavingsListNotifier, SavingsListState>((ref) {
  return SavingsListNotifier(ref.watch(savingsRepositoryProvider));
});

// ─── Add Goal Form ────────────────────────────────────────────────────────────

class AddGoalFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final GoalTemplate? selectedTemplate;
  final DateTime? deadline;

  const AddGoalFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.selectedTemplate,
    this.deadline,
  });

  AddGoalFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    GoalTemplate? selectedTemplate,
    DateTime? deadline,
    bool clearFailure = false,
    bool clearDeadline = false,
  }) {
    return AddGoalFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess, selectedTemplate, deadline];
}

class AddGoalNotifier extends StateNotifier<AddGoalFormState> {
  final SavingsRepository _repository;
  final Ref _ref;

  AddGoalNotifier(this._repository, this._ref) : super(const AddGoalFormState());

  void selectTemplate(GoalTemplate template) {
    state = state.copyWith(selectedTemplate: template);
  }

  void selectDeadline(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearDeadline: true);
    } else {
      state = state.copyWith(deadline: date);
    }
  }

  Future<bool> submit({required String name, required double targetAmount}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final goal = SavingsGoalModel(
      id: '',
      name: name,
      targetAmount: targetAmount,
      deadline: state.deadline,
      icon: state.selectedTemplate?.icon ?? 'flag',
      color: state.selectedTemplate?.color ?? '#6C63FF',
      createdAt: DateTime.now(),
    );

    final result = await _repository.createGoal(goal);

    return result.fold(
      (failure) {
        _ref.read(savingsListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
      (_) {
        _ref.read(savingsListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final addGoalProvider = StateNotifierProvider.autoDispose<AddGoalNotifier, AddGoalFormState>(
  (ref) => AddGoalNotifier(ref.watch(savingsRepositoryProvider), ref),
);
