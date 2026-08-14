import '../../core/network/dio_client.dart';
import '../../core/storage/token_storage.dart';

/// User session data returned by auth endpoints.
class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final bool emailVerified;
  final bool isBiometricEnabled;
  final String avatarColor;
  final String baseCurrency;
  final double monthlyIncomeGoal;
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.emailVerified,
    this.isBiometricEnabled = false,
    required this.avatarColor,
    required this.baseCurrency,
    required this.monthlyIncomeGoal,
  });
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    name: (j['name'] ?? j['fullName'] ?? '') as String,
    email: j['email'] as String,
    phone: j['phone'] as String?,
    emailVerified: (j['emailVerified'] ?? j['isEmailVerified'] ?? false) as bool,
    isBiometricEnabled: (j['isBiometricEnabled'] ?? false) as bool,
    avatarColor: j['avatarColor'] as String? ?? '#6C5CE7',
    baseCurrency: (j['baseCurrency'] ?? j['currency'] ?? 'INR') as String,
    monthlyIncomeGoal: (j['monthlyIncomeGoal'] as num?)?.toDouble() ?? 120000,
  );
}

class AuthResult {
  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final String? otp;
  final String? message;
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.otp,
    this.message,
  });
}

/// Repository for all auth API calls.
class AuthRepository {
  const AuthRepository._();

  /// Register a new account.
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final res = await dioClient.post(ApiEndpoints.authRegister, data: {
      'name': name,
      'email': email,
      'password': password,
      'rememberMe': rememberMe,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Registration failed');
    }
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      otp: data['otp'] as String?,
      message: data['message'] as String?,
    );
  }

  /// Login with email + password.
  static Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final res = await dioClient.post(ApiEndpoints.authLogin, data: {
      'email': email,
      'password': password,
      'rememberMe': rememberMe,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Login failed');
    }
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user.id,
      email: user.email,
      name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  /// Send a phone OTP (Android phone login).
  static Future<String> sendPhoneOtp({required String phone}) async {
    final res = await dioClient.post(ApiEndpoints.authPhoneSend, data: {
      'phone': phone,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Could not send phone OTP');
    }
    return data['otp'] as String? ?? '';
  }

  /// Verify phone OTP — auto-creates user if new phone.
  static Future<AuthResult> verifyPhoneOtp({
    required String phone,
    required String code,
    bool rememberMe = false,
  }) async {
    final res = await dioClient.post(ApiEndpoints.authPhoneVerify, data: {
      'phone': phone,
      'code': code,
      'rememberMe': rememberMe,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['message'] as String? ?? 'Phone verification failed');
    }
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user.id,
      email: user.email,
      name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  /// Toggle biometric login on/off (for current user).
  static Future<bool> toggleBiometric({required bool enabled}) async {
    final res = await dioClient.patch(ApiEndpoints.authBiometric, data: {
      'enabled': enabled,
    });
    final data = res.data as Map<String, dynamic>;
    return data['ok'] == true;
  }

  /// Verify biometric (Android fingerprint / Face ID) and log in.
  /// The app calls `local_auth` first. On success it sends the result here.
  static Future<AuthResult> biometricLogin({
    required String email,
    String bioToken = 'android-biometric-verified',
  }) async {
    final res = await dioClient.post(ApiEndpoints.authBiometricVerify, data: {
      'email': email,
      'bioToken': bioToken,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Biometric verification failed');
    }
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user.id, email: user.email, name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  // --------------------------------------------------
  // OTP-based auth
  // --------------------------------------------------

  /// Send an OTP to the given email.
  static Future<String> sendOtp({
    required String email,
    String purpose = 'register',
    String? password,
  }) async {
    final body = <String, dynamic>{'email': email, 'purpose': purpose};
    if (password != null) body['password'] = password;
    final res = await dioClient.post(ApiEndpoints.authOtpSend, data: body);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Could not send OTP');
    }
    return data['otp'] as String? ?? '';
  }

  /// Verify an OTP.
  static Future<AuthResult> verifyOtp({
    required String email,
    required String code,
    String purpose = 'register',
    String? name,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'email': email, 'code': code, 'purpose': purpose,
    };
    if (name != null) body['name'] = name;
    if (password != null) body['password'] = password;
    final res = await dioClient.post(ApiEndpoints.authOtpVerify, data: body);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'OTP verification failed');
    }
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user.id, email: user.email, name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  // --------------------------------------------------
  // Password reset
  // --------------------------------------------------

  /// Request a password-reset email.
  static Future<String> forgotPassword({required String email}) async {
    final res = await dioClient.post(ApiEndpoints.authForgotPassword, data: {
      'email': email,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Could not send reset email');
    }
    return data['message'] as String? ?? 'Check your email';
  }

  /// Set a new password using the reset code.
  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await dioClient.post(ApiEndpoints.authResetPassword, data: {
      'email': email, 'code': code, 'newPassword': newPassword,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AuthException(data['error'] as String? ?? 'Password reset failed');
    }
  }

  // --------------------------------------------------
  // Session
  // --------------------------------------------------

  /// Logout — clear local tokens and notify server.
  static Future<void> logout() async {
    try {
      await dioClient.post(ApiEndpoints.authLogout);
    } catch (_) {}
    await TokenStorage.clearAll();
  }

  /// Get the currently-authenticated user from the server.
  static Future<AuthUser?> getMe() async {
    try {
      final res = await dioClient.get(ApiEndpoints.authMe);
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] == true) {
        return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      }
    } catch (_) {
      await TokenStorage.clearAll();
    }
    return null;
  }
}


class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
