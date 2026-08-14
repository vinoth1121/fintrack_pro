import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(ref.watch(dioProvider));
});

class ChatRemoteDataSource {
  final Dio _dio;
  ChatRemoteDataSource(this._dio);

  Future<ChatResponseModel> sendMessage({
    String? conversationId,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final response = await _dio.post('/ai/chat', data: {
      if (conversationId != null) 'conversationId': conversationId,
      'message': message,
      if (history != null) 'messages': history,
    },);
    return ChatResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatConversationModel>> getConversations() async {
    final response = await _dio.get('/ai/conversations');
    return (response.data as List)
        .map((e) => ChatConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversationModel> getConversation(String id) async {
    final response = await _dio.get('/ai/conversations/$id');
    return ChatConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteConversation(String id) async {
    await _dio.delete('/ai/conversations/$id');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(chatRemoteDataSourceProvider));
});

class ChatRepository {
  final ChatRemoteDataSource _remote;
  ChatRepository(this._remote);

  Future<Either<Failure, ChatResponseModel>> sendMessage({
    String? conversationId,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    try {
      return Right(await _remote.sendMessage(
        conversationId: conversationId,
        message: message,
        history: history,
      ),);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, List<ChatConversationModel>>> getConversations() async {
    try {
      return Right(await _remote.getConversations());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, ChatConversationModel>> getConversation(String id) async {
    try {
      return Right(await _remote.getConversation(id));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
