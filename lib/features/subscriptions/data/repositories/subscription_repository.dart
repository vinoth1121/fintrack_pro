import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final subscriptionRemoteDataSourceProvider = Provider<SubscriptionRemoteDataSource>((ref) {
  return SubscriptionRemoteDataSource(ref.watch(dioProvider));
});

class SubscriptionRemoteDataSource {
  final Dio _dio;
  SubscriptionRemoteDataSource(this._dio);

  Future<({List<SubscriptionModel> items, double monthlyTotal})> getSubscriptions() async {
    final response = await _dio.get('/subscriptions');
    final data = response.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List).map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>)).toList(),
      monthlyTotal: (data['monthlyTotal'] as num).toDouble(),
    );
  }

  Future<SubscriptionModel> createSubscription(SubscriptionModel sub) async {
    final response = await _dio.post('/subscriptions', data: sub.toCreateJson());
    return SubscriptionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSubscription(String id) async {
    await _dio.delete('/subscriptions/$id');
  }

  Future<SubscriptionModel> updateStatus(String id, String status) async {
    final response = await _dio.patch('/subscriptions/$id', data: {'status': status});
    return SubscriptionModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(subscriptionRemoteDataSourceProvider));
});

class SubscriptionRepository {
  final SubscriptionRemoteDataSource _remote;
  SubscriptionRepository(this._remote);

  Future<Either<Failure, ({List<SubscriptionModel> items, double monthlyTotal})>> getSubscriptions() async {
    try {
      return Right(await _remote.getSubscriptions());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, SubscriptionModel>> createSubscription(SubscriptionModel sub) async {
    try {
      return Right(await _remote.createSubscription(sub));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteSubscription(String id) async {
    try {
      await _remote.deleteSubscription(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, SubscriptionModel>> updateStatus(String id, String status) async {
    try {
      return Right(await _remote.updateStatus(id, status));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
