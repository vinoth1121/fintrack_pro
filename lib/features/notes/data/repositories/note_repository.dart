import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

final noteRemoteDataSourceProvider = Provider<NoteRemoteDataSource>((ref) {
  return NoteRemoteDataSource(ref.watch(dioProvider));
});

class NoteRemoteDataSource {
  final Dio _dio;
  NoteRemoteDataSource(this._dio);

  Future<List<NoteModel>> getNotes() async {
    final response = await _dio.get('/notes');
    return (response.data as List).map((e) => NoteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<NoteModel> createNote(NoteModel note) async {
    final response = await _dio.post('/notes', data: note.toCreateJson());
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NoteModel> updateNote(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/notes/$id', data: data);
    return NoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteNote(String id) async {
    await _dio.delete('/notes/$id');
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(noteRemoteDataSourceProvider));
});

class NoteRepository {
  final NoteRemoteDataSource _remote;
  NoteRepository(this._remote);

  Future<Either<Failure, List<NoteModel>>> getNotes() async {
    try {
      return Right(await _remote.getNotes());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, NoteModel>> createNote(NoteModel note) async {
    try {
      return Right(await _remote.createNote(note));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, NoteModel>> updateNote(String id, Map<String, dynamic> data) async {
    try {
      return Right(await _remote.updateNote(id, data));
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Future<Either<Failure, void>> deleteNote(String id) async {
    try {
      await _remote.deleteNote(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }
}
