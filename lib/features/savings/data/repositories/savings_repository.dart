import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/savings_goal_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final savingsRemoteDataSourceProvider = Provider<SavingsRemoteDataSource>((ref) {
  return SavingsRemoteDataSource(ref.watch(dioProvider));
});

class SavingsRemoteDataSource {
  final Dio _dio;
  SavingsRemoteDataSource(this._dio);

  Future<List<SavingsGoalModel>> getGoals() async {
    final response = await _dio.get('/savings');
    return (response.data as List)
        .map((e) => SavingsGoalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavingsGoalModel> createGoal(SavingsGoalModel goal) async {
    final response = await _dio.post('/savings', data: goal.toCreateJson());
    return SavingsGoalModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SavingsGoalModel> contribute(String goalId, double amount, {String? notes}) async {
    final response = await _dio.post('/savings/$goalId/contribute', data: {
      'amount': amount,
      if (notes != null) 'notes': notes,
    },);
    return SavingsGoalModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGoal(String id) async {
    await _dio.delete('/savings/$id');
  }
}

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository(ref.watch(savingsRemoteDataSourceProvider));
});

class SavingsRepository {
  final SavingsRemoteDataSource _remote;
  SavingsRepository(this._remote);

  Future<Either<Failure, List<SavingsGoalModel>>> getGoals() async {
    try {
      return Right(await _remote.getGoals());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, SavingsGoalModel>> createGoal(SavingsGoalModel goal) async {
    try {
      return Right(await _remote.createGoal(goal));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, SavingsGoalModel>> contribute(String goalId, double amount, {String? notes}) async {
    try {
      return Right(await _remote.contribute(goalId, amount, notes: notes));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteGoal(String id) async {
    try {
      await _remote.deleteGoal(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
