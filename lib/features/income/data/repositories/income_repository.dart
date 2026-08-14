import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/income_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final incomeRemoteDataSourceProvider = Provider<IncomeRemoteDataSource>((ref) {
  return IncomeRemoteDataSource(ref.watch(dioProvider));
});

class IncomeRemoteDataSource {
  final Dio _dio;
  IncomeRemoteDataSource(this._dio);

  Future<PaginatedIncomeModel> getIncome({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/income', queryParameters: {'page': page, 'limit': limit});
    return PaginatedIncomeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IncomeModel> createIncome(IncomeModel income) async {
    final response = await _dio.post('/income', data: income.toCreateJson());
    return IncomeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteIncome(String id) async {
    await _dio.delete('/income/$id');
  }
}

final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  return IncomeRepository(ref.watch(incomeRemoteDataSourceProvider));
});

class IncomeRepository {
  final IncomeRemoteDataSource _remote;
  IncomeRepository(this._remote);

  Future<Either<Failure, PaginatedIncomeModel>> getIncome({int page = 1}) async {
    try {
      return Right(await _remote.getIncome(page: page));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, IncomeModel>> createIncome(IncomeModel income) async {
    try {
      return Right(await _remote.createIncome(income));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteIncome(String id) async {
    try {
      await _remote.deleteIncome(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
