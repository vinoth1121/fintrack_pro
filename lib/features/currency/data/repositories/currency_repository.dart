import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/currency_entity.dart';
import '../../../../core/errors/failures.dart';

/// Uses the free, no-API-key-required exchangerate-api.com open endpoint.
/// Rates update daily, which is sufficient for personal budgeting use —
/// this is not a trading app requiring real-time tick data.
const _kBaseUrl = 'https://open.er-api.com/v6/latest';
const _kCacheKey = 'currency_rates_cache';
const _kCacheTimestampKey = 'currency_rates_cache_ts';
const _kCacheBaseKey = 'currency_rates_cache_base';

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  // Deliberately uses a fresh Dio instance rather than the app's authenticated
  // dioProvider — this is a public, unauthenticated third-party API and should
  // never carry the user's Bearer token.
  return CurrencyRepository(Dio());
});

class CurrencyRepository {
  final Dio _dio;
  CurrencyRepository(this._dio);

  Future<Either<Failure, ExchangeRatesEntity>> getRates({String base = 'USD'}) async {
    try {
      final response = await _dio.get('$_kBaseUrl/$base');
      final data = response.data as Map<String, dynamic>;

      if (data['result'] != 'success') {
        final cached = await _fallbackToCache(base);
        return cached ?? const Left(ServerFailure(message: 'Unable to fetch exchange rates.'));
      }

      final rawRates = data['rates'] as Map<String, dynamic>;
      final rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
      final entity = ExchangeRatesEntity(baseCurrency: base, rates: rates, fetchedAt: DateTime.now());

      await _saveToCache(entity);
      return Right(entity);
    } on DioException catch (_) {
      // Network failure — fall back to cached rates if available
      final cached = await _fallbackToCache(base);
      return cached ?? const Left(NetworkFailure());
    } catch (_) {
      final cached = await _fallbackToCache(base);
      return cached ?? const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, ExchangeRatesEntity>?> _fallbackToCache(String base) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedBase = prefs.getString(_kCacheBaseKey);
    if (cachedBase != base) return null;

    final cachedJson = prefs.getString(_kCacheKey);
    final cachedTs = prefs.getInt(_kCacheTimestampKey);
    if (cachedJson == null || cachedTs == null) return null;

    final rates = (jsonDecode(cachedJson) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    return Right(ExchangeRatesEntity(
      baseCurrency: base,
      rates: rates,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(cachedTs),
    ),);
  }

  Future<void> _saveToCache(ExchangeRatesEntity entity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(entity.rates));
    await prefs.setInt(_kCacheTimestampKey, entity.fetchedAt.millisecondsSinceEpoch);
    await prefs.setString(_kCacheBaseKey, entity.baseCurrency);
  }
}
