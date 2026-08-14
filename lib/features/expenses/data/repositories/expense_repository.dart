import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

// ─── Remote Data Source ──────────────────────────────────────────────────────

final expenseRemoteDataSourceProvider = Provider<ExpenseRemoteDataSource>((ref) {
  return ExpenseRemoteDataSource(ref.watch(dioProvider));
});

class ExpenseRemoteDataSource {
  final Dio _dio;
  ExpenseRemoteDataSource(this._dio);

  Future<PaginatedExpensesModel> getExpenses({
    int page = 1,
    int limit = 20,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    final response = await _dio.get('/expenses', queryParameters: {
      'page': page,
      'limit': limit,
      if (categoryId != null) 'categoryId': categoryId,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (search != null && search.isNotEmpty) 'search': search,
    },);
    return PaginatedExpensesModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExpenseModel> getExpense(String id) async {
    final response = await _dio.get('/expenses/$id');
    return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExpenseModel> createExpense(ExpenseModel expense) async {
    final response = await _dio.post('/expenses', data: expense.toCreateJson());
    return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExpenseModel> updateExpense(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/expenses/$id', data: data);
    return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String id) async {
    await _dio.delete('/expenses/$id');
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(expenseRemoteDataSourceProvider));
});

class ExpenseRepository {
  final ExpenseRemoteDataSource _remote;
  ExpenseRepository(this._remote);

  Future<Either<Failure, PaginatedExpensesModel>> getExpenses({
    int page = 1,
    int limit = 20,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    try {
      final result = await _remote.getExpenses(
        page: page, limit: limit, categoryId: categoryId,
        startDate: startDate, endDate: endDate, search: search,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, ExpenseModel>> createExpense(ExpenseModel expense) async {
    try {
      return Right(await _remote.createExpense(expense));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, ExpenseModel>> getExpense(String id) async {
    try {
      return Right(await _remote.getExpense(id));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteExpense(String id) async {
    try {
      await _remote.deleteExpense(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
