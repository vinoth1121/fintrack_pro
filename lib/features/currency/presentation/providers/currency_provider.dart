import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/currency_entity.dart';
import '../../data/repositories/currency_repository.dart';
import '../../../../core/errors/failures.dart';

enum RatesStatus { initial, loading, loaded, error }

class CurrencyConverterState extends Equatable {
  final RatesStatus status;
  final ExchangeRatesEntity? rates;
  final Failure? failure;
  final String fromCurrency;
  final String toCurrency;
  final double amount;

  const CurrencyConverterState({
    this.status = RatesStatus.initial,
    this.rates,
    this.failure,
    this.fromCurrency = 'USD',
    this.toCurrency = 'EUR',
    this.amount = 100,
  });

  double? get convertedAmount => rates?.convert(fromCurrency, toCurrency, amount);

  double? get exchangeRate => rates?.convert(fromCurrency, toCurrency, 1);

  CurrencyConverterState copyWith({
    RatesStatus? status,
    ExchangeRatesEntity? rates,
    Failure? failure,
    String? fromCurrency,
    String? toCurrency,
    double? amount,
  }) {
    return CurrencyConverterState(
      status: status ?? this.status,
      rates: rates ?? this.rates,
      failure: failure,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      amount: amount ?? this.amount,
    );
  }

  @override
  List<Object?> get props => [status, rates, failure, fromCurrency, toCurrency, amount];
}

class CurrencyConverterNotifier extends StateNotifier<CurrencyConverterState> {
  final CurrencyRepository _repository;

  CurrencyConverterNotifier(this._repository) : super(const CurrencyConverterState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: RatesStatus.loading);
    final result = await _repository.getRates(base: state.fromCurrency);

    result.fold(
      (failure) => state = state.copyWith(status: RatesStatus.error, failure: failure),
      (rates) => state = state.copyWith(status: RatesStatus.loaded, rates: rates),
    );
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void setFromCurrency(String code) {
    state = state.copyWith(fromCurrency: code);
    load(); // Re-fetch with new base for maximum precision
  }

  void setToCurrency(String code) {
    state = state.copyWith(toCurrency: code);
  }

  void swapCurrencies() {
    final newFrom = state.toCurrency;
    final newTo = state.fromCurrency;
    state = state.copyWith(fromCurrency: newFrom, toCurrency: newTo);
    load();
  }
}

final currencyConverterProvider =
    StateNotifierProvider<CurrencyConverterNotifier, CurrencyConverterState>((ref) {
  return CurrencyConverterNotifier(ref.watch(currencyRepositoryProvider));
});
