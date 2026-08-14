import 'package:equatable/equatable.dart';

class CurrencyEntity extends Equatable {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const CurrencyEntity({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
  });

  @override
  List<Object?> get props => [code, name, symbol, flag];
}

class ExchangeRatesEntity extends Equatable {
  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime fetchedAt;

  const ExchangeRatesEntity({
    required this.baseCurrency,
    required this.rates,
    required this.fetchedAt,
  });

  double? convert(String from, String to, double amount) {
    if (from == to) return amount;
    // Rates are relative to baseCurrency. Convert via base.
    final fromRate = from == baseCurrency ? 1.0 : rates[from];
    final toRate = to == baseCurrency ? 1.0 : rates[to];
    if (fromRate == null || toRate == null) return null;
    final amountInBase = amount / fromRate;
    return amountInBase * toRate;
  }

  bool get isStale => DateTime.now().difference(fetchedAt).inHours >= 12;

  @override
  List<Object?> get props => [baseCurrency, rates, fetchedAt];
}

/// Common currencies for quick selection — full list comes from the API response.
abstract final class CommonCurrencies {
  static const all = [
    CurrencyEntity(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    CurrencyEntity(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    CurrencyEntity(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    CurrencyEntity(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    CurrencyEntity(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    CurrencyEntity(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
    CurrencyEntity(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦'),
    CurrencyEntity(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flag: '🇨🇭'),
    CurrencyEntity(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    CurrencyEntity(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flag: '🇸🇬'),
    CurrencyEntity(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪'),
    CurrencyEntity(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
  ];

  static CurrencyEntity byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => CurrencyEntity(code: code, name: code, symbol: code, flag: '🏳️'));
}
