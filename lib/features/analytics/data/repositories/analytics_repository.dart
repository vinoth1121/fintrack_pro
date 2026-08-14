import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final analyticsRemoteDataSourceProvider = Provider<AnalyticsRemoteDataSource>((ref) {
  return AnalyticsRemoteDataSource(ref.watch(dioProvider));
});

class AnalyticsRemoteDataSource {
  final Dio _dio;
  AnalyticsRemoteDataSource(this._dio);

  Future<List<CategoryBreakdownEntity>> getCategoryBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _dio.get('/analytics/category-breakdown', queryParameters: {
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    },);
    return (response.data as List).map((e) {
      final json = e as Map<String, dynamic>;
      return CategoryBreakdownEntity(
        name: json['name'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        amount: (json['amount'] as num).toDouble(),
        transactionCount: json['transactionCount'] as int,
        percentage: (json['percentage'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<MonthlyTrendEntity>> getMonthlyTrend({int months = 6}) async {
    final response = await _dio.get('/analytics/monthly-trend', queryParameters: {'months': months});
    return (response.data as List).map((e) {
      final json = e as Map<String, dynamic>;
      return MonthlyTrendEntity(
        month: json['month'] as String,
        income: (json['income'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
      );
    }).toList();
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(analyticsRemoteDataSourceProvider));
});

class AnalyticsRepository {
  final AnalyticsRemoteDataSource _remote;
  AnalyticsRepository(this._remote);

  Future<Either<Failure, List<CategoryBreakdownEntity>>> getCategoryBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return Right(await _remote.getCategoryBreakdown(startDate: startDate, endDate: endDate));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, List<MonthlyTrendEntity>>> getMonthlyTrend({int months = 6}) async {
    try {
      return Right(await _remote.getMonthlyTrend(months: months));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
