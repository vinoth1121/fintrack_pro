import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Base failure class — all domain-level errors extend this.
/// UI layer maps Failure → user-visible message. Never expose raw exceptions to UI.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

// ─── Network Failures ────────────────────────────────────────────────────────

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection.', super.code});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = 'The request timed out. Please try again.', super.code});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Your session has expired. Please log in again.', super.code});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.message = 'You do not have permission to perform this action.', super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'The requested resource was not found.', super.code});
}

class ConflictFailure extends Failure {
  const ConflictFailure({required super.message, super.code});
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

// ─── Local Failures ──────────────────────────────────────────────────────────

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Failed to load data from cache.', super.code});
}

class StorageFailure extends Failure {
  const StorageFailure({required super.message, super.code});
}

// ─── Auth Failures ───────────────────────────────────────────────────────────

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password.',
    super.code,
  });
}

class EmailNotVerifiedFailure extends Failure {
  const EmailNotVerifiedFailure({
    super.message = 'Please verify your email before logging in.',
    super.code,
  });
}

class AccountDisabledFailure extends Failure {
  const AccountDisabledFailure({
    super.message = 'Your account has been disabled. Please contact support.',
    super.code,
  });
}

class OtpExpiredFailure extends Failure {
  const OtpExpiredFailure({
    super.message = 'The verification code has expired. Please request a new one.',
    super.code,
  });
}

class OtpInvalidFailure extends Failure {
  const OtpInvalidFailure({
    super.message = 'The verification code is incorrect.',
    super.code,
  });
}

// ─── Business Logic Failures ─────────────────────────────────────────────────

class InsufficientDataFailure extends Failure {
  const InsufficientDataFailure({required super.message, super.code});
}

class OperationFailure extends Failure {
  const OperationFailure({required super.message, super.code});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
  });
}

Failure mapDioErrorToFailure(DioException error) {
  final statusCode = error.response?.statusCode;
  final serverMessage = error.response?.data is Map<String, dynamic>
      ? error.response!.data['message']?.toString()
      : null;

  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const TimeoutFailure();
  }

  if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.unknown) {
    return const NetworkFailure();
  }

  if (statusCode == 400) {
    return ValidationFailure(message: serverMessage ?? 'The request could not be processed.', code: statusCode.toString());
  }
  if (statusCode == 401) {
    return const UnauthorizedFailure();
  }
  if (statusCode == 403) {
    return const ForbiddenFailure();
  }
  if (statusCode == 404) {
    return const NotFoundFailure();
  }
  if (statusCode == 409) {
    return ConflictFailure(message: serverMessage ?? 'The request conflicts with current data.', code: statusCode.toString());
  }
  if (statusCode != null && statusCode >= 500) {
    return ServerFailure(message: serverMessage ?? 'The server is currently unavailable.', code: statusCode.toString());
  }

  return UnexpectedFailure(message: serverMessage ?? 'An unexpected error occurred. Please try again.');
}
