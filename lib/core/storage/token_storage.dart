import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT tokens + user session.
class TokenStorage {
  TokenStorage._();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken = 'ft_access_token';
  static const _keyRefreshToken = 'ft_refresh_token';
  static const _keyUserId = 'ft_user_id';
  static const _keyUserEmail = 'ft_user_email';
  static const _keyUserName = 'ft_user_name';

  static Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  static Future<String?> getUserId() => _storage.read(key: _keyUserId);
  static Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);
  static Future<String?> getUserName() => _storage.read(key: _keyUserName);

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    String? name,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyUserEmail, value: email),
      if (name != null) _storage.write(key: _keyUserName, value: name),
    ]);
  }

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
