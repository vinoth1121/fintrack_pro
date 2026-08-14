import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/auth_entities.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/errors/failures.dart';

// ─── State ───────────────────────────────────────────────────────────────────

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;
  final Failure? failure;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.failure,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    Failure? failure,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, user, failure];
}

// ─── Form States ─────────────────────────────────────────────────────────────

class LoginFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final bool obscurePassword;

  const LoginFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.obscurePassword = true,
  });

  LoginFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    bool? obscurePassword,
    bool clearFailure = false,
  }) {
    return LoginFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess, obscurePassword];
}

class RegisterFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool acceptedTerms;

  const RegisterFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.acceptedTerms = false,
  });

  RegisterFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    bool? acceptedTerms,
    bool clearFailure = false,
  }) {
    return RegisterFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, failure, isSuccess, obscurePassword,
    obscureConfirmPassword, acceptedTerms,
  ];
}

class OtpFormState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isSuccess;
  final bool isResending;
  final int resendCountdown;

  const OtpFormState({
    this.isLoading = false,
    this.failure,
    this.isSuccess = false,
    this.isResending = false,
    this.resendCountdown = 60,
  });

  bool get canResend => resendCountdown == 0 && !isResending;

  OtpFormState copyWith({
    bool? isLoading,
    Failure? failure,
    bool? isSuccess,
    bool? isResending,
    int? resendCountdown,
    bool clearFailure = false,
  }) {
    return OtpFormState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSuccess: isSuccess ?? this.isSuccess,
      isResending: isResending ?? this.isResending,
      resendCountdown: resendCountdown ?? this.resendCountdown,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, isSuccess, isResending, resendCountdown];
}

// ─── Notifiers ────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepositoryImpl _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final result = await _repository.getCurrentUser();
    result.fold(
      (failure) => state = const AuthState(status: AuthStatus.unauthenticated),
      (user) => state = AuthState(status: AuthStatus.authenticated, user: user),
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(UserEntity user) {
    state = state.copyWith(user: user, status: AuthStatus.authenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

// ─── Login Provider ───────────────────────────────────────────────────────────

class LoginNotifier extends StateNotifier<LoginFormState> {
  final AuthRepositoryImpl _repository;
  final Ref _ref;

  LoginNotifier(this._repository, this._ref) : super(const LoginFormState());

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.login(email: email, password: password);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
        return false;
      },
      (tokens) {
        _ref.read(authProvider.notifier).updateUser(tokens.user);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final loginProvider =
    StateNotifierProvider.autoDispose<LoginNotifier, LoginFormState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginNotifier(repo, ref);
});

// ─── Register Provider ────────────────────────────────────────────────────────

class RegisterNotifier extends StateNotifier<RegisterFormState> {
  final AuthRepositoryImpl _repository;

  RegisterNotifier(this._repository) : super(const RegisterFormState());

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void toggleConfirmPasswordVisibility() {
    state = state.copyWith(
      obscureConfirmPassword: !state.obscureConfirmPassword,
    );
  }

  void toggleTerms() {
    state = state.copyWith(acceptedTerms: !state.acceptedTerms);
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.register(
      fullName: fullName,
      email: email,
      password: password,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

final registerProvider =
    StateNotifierProvider.autoDispose<RegisterNotifier, RegisterFormState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    return RegisterNotifier(repo);
  },
);

// ─── OTP Provider ─────────────────────────────────────────────────────────────

class OtpNotifier extends StateNotifier<OtpFormState> {
  final AuthRepositoryImpl _repository;
  final Ref _ref;

  OtpNotifier(this._repository, this._ref) : super(const OtpFormState()) {
    _startCountdown();
  }

  void _startCountdown() async {
    while (state.resendCountdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        state = state.copyWith(
          resendCountdown: state.resendCountdown - 1,
        );
      }
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _repository.verifyEmail(email: email, otp: otp);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
        return false;
      },
      (tokens) {
        _ref.read(authProvider.notifier).updateUser(tokens.user);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }

  Future<void> resendOtp(String email) async {
    if (!state.canResend) return;
    state = state.copyWith(isResending: true);
    await _repository.sendEmailVerification(email);
    state = state.copyWith(isResending: false, resendCountdown: 60);
    _startCountdown();
  }
}

final otpProvider =
    StateNotifierProvider.autoDispose<OtpNotifier, OtpFormState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return OtpNotifier(repo, ref);
});
