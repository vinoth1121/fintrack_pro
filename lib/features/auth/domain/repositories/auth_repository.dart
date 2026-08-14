import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/auth_entities.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthTokensEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> register({
    required String fullName,
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> sendEmailVerification(String email);

  Future<Either<Failure, AuthTokensEntity>> verifyEmail({
    required String email,
    required String otp,
  });

  Future<Either<Failure, void>> sendPasswordReset(String email);

  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserEntity>> getCurrentUser();

  Future<Either<Failure, bool>> isAuthenticated();
}
