import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';

// ─── Edit Profile Form ────────────────────────────────────────────────────────

class EditProfileFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;

  const EditProfileFormState({this.isLoading = false, this.failure, this.isSuccess = false});

  EditProfileFormState copyWith({bool? isLoading, Failure? failure, bool? isSuccess, bool clearFailure = false}) {
    return EditProfileFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess];
}

class EditProfileNotifier extends StateNotifier<EditProfileFormState> {
  final Ref _ref;

  EditProfileNotifier(this._ref) : super(const EditProfileFormState());

  Future<bool> save({
    required String fullName,
    String? phone,
    String? currency,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.patch('/users/me', data: {
        'fullName': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (currency != null && currency.isNotEmpty) 'currency': currency,
      },);

      final data = response.data as Map<String, dynamic>;
      final currentUser = _ref.read(authProvider).user;
      if (currentUser != null) {
        final updated = currentUser.copyWith(
          fullName: data['fullName'] as String? ?? fullName,
          phone: data['phone'] as String?,
          currency: data['currency'] as String? ?? currentUser.currency,
        );
        _ref.read(authProvider.notifier).updateUser(updated);
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, failure: mapDioErrorToFailure(e));
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, failure: const UnexpectedFailure());
      return false;
    }
  }
}

final editProfileProvider =
    StateNotifierProvider.autoDispose<EditProfileNotifier, EditProfileFormState>(
  (ref) => EditProfileNotifier(ref),
);

// ─── Change Password Form ─────────────────────────────────────────────────────

class ChangePasswordFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;

  const ChangePasswordFormState({this.isLoading = false, this.failure, this.isSuccess = false});

  ChangePasswordFormState copyWith({bool? isLoading, Failure? failure, bool? isSuccess, bool clearFailure = false}) {
    return ChangePasswordFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess];
}

class ChangePasswordNotifier extends StateNotifier<ChangePasswordFormState> {
  final Ref _ref;

  ChangePasswordNotifier(this._ref) : super(const ChangePasswordFormState());

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/users/me/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, failure: mapDioErrorToFailure(e));
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, failure: const UnexpectedFailure());
      return false;
    }
  }
}

final changePasswordProvider =
    StateNotifierProvider.autoDispose<ChangePasswordNotifier, ChangePasswordFormState>(
  (ref) => ChangePasswordNotifier(ref),
);
