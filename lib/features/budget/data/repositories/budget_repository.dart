import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final budgetRemoteDataSourceProvider = Provider<BudgetRemoteDataSource>((ref) {
  return BudgetRemoteDataSource(ref.watch(dioProvider));
});

class BudgetRemoteDataSource {
  final Dio _dio;
  BudgetRemoteDataSource(this._dio);

  Future<List<BudgetModel>> getBudgets() async {
    final response = await _dio.get('/budgets');
    return (response.data as List)
        .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetModel> createBudget(BudgetModel budget) async {
    final response = await _dio.post('/budgets', data: budget.toCreateJson());
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BudgetModel> updateBudget(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/budgets/$id', data: data);
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBudget(String id) async {
    await _dio.delete('/budgets/$id');
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(budgetRemoteDataSourceProvider));
});

class BudgetRepository {
  final BudgetRemoteDataSource _remote;
  BudgetRepository(this._remote);

  Future<Either<Failure, List<BudgetModel>>> getBudgets() async {
    try {
      return Right(await _remote.getBudgets());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, BudgetModel>> createBudget(BudgetModel budget) async {
    try {
      return Right(await _remote.createBudget(budget));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteBudget(String id) async {
    try {
      await _remote.deleteBudget(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
