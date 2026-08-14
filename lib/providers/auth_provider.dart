import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';

/// Auth state.
class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final bool loading;
  final String? error;
  const AuthState({this.status = AuthStatus.unknown, this.user, this.loading = false, this.error});

  AuthState copyWith({AuthStatus? status, AuthUser? user, bool? loading, String? error}) =>
    AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
    );
}

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Auth notifier — manages login/logout/session.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await AuthRepository.getMe();
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await AuthRepository.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  void setAuthResult(AuthResult result) {
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
  }

  void setError(String? error) {
    state = state.copyWith(loading: false, error: error);
  }

  Future<AuthResult?> register(String name, String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await AuthRepository.register(name: name, email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return result;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  Future<void> logout() async {
    await AuthRepository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Convenience provider for the current user.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience provider for auth status.
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});
