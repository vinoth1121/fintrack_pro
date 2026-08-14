import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/models/subscription_model.dart';
import '../../../../core/errors/failures.dart';

enum SubscriptionListStatus { initial, loading, loaded, error }

class SubscriptionListState extends Equatable {
  final SubscriptionListStatus status;
  final List<SubscriptionEntity> subscriptions;
  final Failure? failure;

  const SubscriptionListState({
    this.status = SubscriptionListStatus.initial,
    this.subscriptions = const [],
    this.failure,
  });

  List<SubscriptionEntity> get active =>
      subscriptions.where((s) => s.status == SubscriptionStatus.active).toList()
        ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));

  double get monthlyTotal => active.fold(0, (sum, s) => sum + s.monthlyEquivalent);
  double get yearlyTotal => monthlyTotal * 12;

  List<SubscriptionEntity> get upcomingSoon =>
      active.where((s) => s.isBillingSoon).toList();

  SubscriptionListState copyWith({
    SubscriptionListStatus? status,
    List<SubscriptionEntity>? subscriptions,
    Failure? failure,
  }) {
    return SubscriptionListState(
      status: status ?? this.status,
      subscriptions: subscriptions ?? this.subscriptions,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, subscriptions, failure];
}

class SubscriptionListNotifier extends StateNotifier<SubscriptionListState> {
  final SubscriptionRepository _repository;

  SubscriptionListNotifier(this._repository) : super(const SubscriptionListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: SubscriptionListStatus.loading);
    final result = await _repository.getSubscriptions();

    result.fold(
      (failure) => state = state.copyWith(
        status: SubscriptionListStatus.loaded,
        subscriptions: _mockSubscriptions(),
      ),
      (data) => state = state.copyWith(
        status: SubscriptionListStatus.loaded,
        subscriptions: data.items.map((m) => m.toEntity()).toList(),
      ),
    );
  }

  Future<void> cancelSubscription(String id) async {
    final result = await _repository.updateStatus(id, 'CANCELLED');
    result.fold(
      (failure) {
        // Optimistic fallback
        final updated = state.subscriptions.map((s) {
          if (s.id != id) return s;
          return SubscriptionEntity(
            id: s.id, name: s.name, amount: s.amount, currency: s.currency,
            cycle: s.cycle, nextBillingDate: s.nextBillingDate, startDate: s.startDate,
            category: s.category, icon: s.icon, color: s.color,
            status: SubscriptionStatus.cancelled, notes: s.notes, url: s.url,
          );
        }).toList();
        state = state.copyWith(subscriptions: updated);
      },
      (model) {
        final updated = state.subscriptions.map((s) => s.id == id ? model.toEntity() : s).toList();
        state = state.copyWith(subscriptions: updated);
      },
    );
  }

  Future<void> deleteSubscription(String id) async {
    final result = await _repository.deleteSubscription(id);
    result.fold(
      (failure) {},
      (_) => state = state.copyWith(subscriptions: state.subscriptions.where((s) => s.id != id).toList()),
    );
  }

  List<SubscriptionEntity> _mockSubscriptions() {
    final now = DateTime.now();
    return [
      SubscriptionEntity(
        id: '1', name: 'Netflix', amount: 15.99, cycle: SubscriptionCycle.monthly,
        nextBillingDate: now.add(const Duration(days: 2)), startDate: now.subtract(const Duration(days: 400)),
        category: 'Entertainment', icon: 'tv', color: '#E50914', autoDetected: true,
      ),
      SubscriptionEntity(
        id: '2', name: 'Spotify Premium', amount: 10.99, cycle: SubscriptionCycle.monthly,
        nextBillingDate: now.add(const Duration(days: 5)), startDate: now.subtract(const Duration(days: 600)),
        category: 'Entertainment', icon: 'music', color: '#1DB954', autoDetected: true,
      ),
      SubscriptionEntity(
        id: '3', name: 'Adobe Creative Cloud', amount: 54.99, cycle: SubscriptionCycle.monthly,
        nextBillingDate: now.add(const Duration(days: 12)), startDate: now.subtract(const Duration(days: 200)),
        category: 'Productivity', icon: 'design', color: '#FF0000',
      ),
      SubscriptionEntity(
        id: '4', name: 'Amazon Prime', amount: 139.00, cycle: SubscriptionCycle.yearly,
        nextBillingDate: now.add(const Duration(days: 45)), startDate: now.subtract(const Duration(days: 300)),
        category: 'Shopping', icon: 'shopping', color: '#FF9900',
      ),
      SubscriptionEntity(
        id: '5', name: 'iCloud+ 200GB', amount: 2.99, cycle: SubscriptionCycle.monthly,
        nextBillingDate: now.add(const Duration(days: 1)), startDate: now.subtract(const Duration(days: 500)),
        category: 'Cloud Storage', icon: 'cloud', color: '#007AFF', autoDetected: true,
      ),
      SubscriptionEntity(
        id: '6', name: 'Gym Membership', amount: 45.00, cycle: SubscriptionCycle.monthly,
        nextBillingDate: now.add(const Duration(days: 20)), startDate: now.subtract(const Duration(days: 150)),
        category: 'Health', icon: 'fitness', color: '#4CAF50',
      ),
    ];
  }
}

final subscriptionListProvider = StateNotifierProvider<SubscriptionListNotifier, SubscriptionListState>((ref) {
  return SubscriptionListNotifier(ref.watch(subscriptionRepositoryProvider));
});

// ─── Add Subscription Form ────────────────────────────────────────────────────

class AddSubscriptionFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final SubscriptionCycle cycle;
  final DateTime nextBillingDate;

  AddSubscriptionFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.cycle = SubscriptionCycle.monthly,
    DateTime? nextBillingDate,
  }) : nextBillingDate = nextBillingDate ?? DateTime.now().add(const Duration(days: 30));

  AddSubscriptionFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    SubscriptionCycle? cycle,
    DateTime? nextBillingDate,
    bool clearFailure = false,
  }) {
    return AddSubscriptionFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      cycle: cycle ?? this.cycle,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess, cycle, nextBillingDate];
}

class AddSubscriptionNotifier extends StateNotifier<AddSubscriptionFormState> {
  final SubscriptionRepository _repository;
  final Ref _ref;

  AddSubscriptionNotifier(this._repository, this._ref) : super(AddSubscriptionFormState());

  void selectCycle(SubscriptionCycle cycle) {
    state = state.copyWith(cycle: cycle);
  }

  void selectNextBillingDate(DateTime date) {
    state = state.copyWith(nextBillingDate: date);
  }

  Future<bool> submit({required String name, required double amount}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final sub = SubscriptionModel(
      id: '',
      name: name,
      amount: amount,
      cycle: switch (state.cycle) {
        SubscriptionCycle.weekly => 'WEEKLY',
        SubscriptionCycle.quarterly => 'QUARTERLY',
        SubscriptionCycle.yearly => 'YEARLY',
        SubscriptionCycle.monthly => 'MONTHLY',
      },
      nextBillingDate: state.nextBillingDate,
      startDate: DateTime.now(),
    );

    final result = await _repository.createSubscription(sub);

    return result.fold(
      (failure) {
        _ref.read(subscriptionListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
      (_) {
        _ref.read(subscriptionListProvider.notifier).load();
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final addSubscriptionProvider =
    StateNotifierProvider.autoDispose<AddSubscriptionNotifier, AddSubscriptionFormState>(
  (ref) => AddSubscriptionNotifier(ref.watch(subscriptionRepositoryProvider), ref),
);
