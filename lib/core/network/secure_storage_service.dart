import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Cross-platform secure storage using SharedPreferences.
/// On Web, flutter_secure_storage is not supported, so we use SharedPreferences.
/// On mobile, you may replace with flutter_secure_storage in the future.
class SecureStorageService {
  // ─── Keys ─────────────────────────────────────────────────────────────────
  static const _keyAccessToken = 'ft_access_token';
  static const _keyRefreshToken = 'ft_refresh_token';
  static const _keyUserId = 'ft_user_id';
  static const _keyBiometricEnabled = 'ft_biometric_enabled';
  static const _keyPinHash = 'ft_pin_hash';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ─── Tokens ───────────────────────────────────────────────────────────────
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_keyAccessToken, accessToken),
      prefs.setString(_keyRefreshToken, refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyRefreshToken);
  }

  // ─── User ─────────────────────────────────────────────────────────────────
  Future<void> saveUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_keyUserId, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserId);
  }

  // ─── Biometric ────────────────────────────────────────────────────────────
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // ─── PIN ──────────────────────────────────────────────────────────────────
  Future<void> savePinHash(String hash) async {
    final prefs = await _prefs;
    await prefs.setString(_keyPinHash, hash);
  }

  Future<String?> getPinHash() async {
    final prefs = await _prefs;
    return prefs.getString(_keyPinHash);
  }

  // ─── Clear ────────────────────────────────────────────────────────────────
  Future<void> clearAuthData() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_keyAccessToken),
      prefs.remove(_keyRefreshToken),
      prefs.remove(_keyUserId),
    ]);
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
