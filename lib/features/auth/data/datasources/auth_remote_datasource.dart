import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../../../../core/network/dio_client.dart';
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(dioProvider));
});

class AuthRemoteDataSource {
  final Dio _dio;
  AuthRemoteDataSource(this._dio);

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(ApiEndpoints.authLogin, data: {
      'email': email,
      'password': password,
    },);
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _dio.post(ApiEndpoints.authRegister, data: {
      'fullName': fullName,
      'email': email,
      'password': password,
    },);
  }

  Future<void> sendEmailVerification(String email) async {
    await _dio.post(ApiEndpoints.authOtpSend, data: {'email': email});
  }

  Future<AuthResponseModel> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final response = await _dio.post(ApiEndpoints.authOtpVerify, data: {
      'email': email,
      'otp': otp,
    },);
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> sendPasswordReset(String email) async {
    await _dio.post(ApiEndpoints.authForgotPassword, data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post(ApiEndpoints.authResetPassword, data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    },);
  }

  Future<void> logout() async {
    await _dio.post(ApiEndpoints.authLogout);
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get(ApiEndpoints.authMe);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
