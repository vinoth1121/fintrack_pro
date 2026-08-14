import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSource(ref.watch(dioProvider));
});

class NotificationRemoteDataSource {
  final Dio _dio;
  NotificationRemoteDataSource(this._dio);

  Future<PaginatedNotificationsModel> getNotifications() async {
    final response = await _dio.get('/notifications');
    return PaginatedNotificationsModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.post('/notifications/read-all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(notificationRemoteDataSourceProvider));
});

class NotificationRepository {
  final NotificationRemoteDataSource _remote;
  NotificationRepository(this._remote);

  Future<Either<Failure, PaginatedNotificationsModel>> getNotifications() async {
    try {
      return Right(await _remote.getNotifications());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> markAsRead(String id) async {
    try {
      await _remote.markAsRead(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> markAllAsRead() async {
    try {
      await _remote.markAllAsRead();
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
