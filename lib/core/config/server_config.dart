import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';
import '../network/dio_client.dart';

/// Lets the app point at a real deployed backend at runtime, instead of only
/// ever supporting `--dart-define=API_BASE_URL=...` at build time.
///
/// This matters for production: [AppConfig.apiBaseUrl] defaults to
/// `10.0.2.2` (Android emulator) or `localhost`, neither of which a real
/// user's phone can ever reach. Before publishing to the Play Store, either:
///   1. Bake the real deployed API URL in via `--dart-define` at build time, or
///   2. Ship a build that lets the user/tester set it once from Settings
///      (this class + the Settings screen "Server connection" card).
class ServerConfig {
  ServerConfig._();
  static const _key = 'fintrack_api_base_url_override';

  /// Applies any saved override to the live [dioClient] at app startup.
  /// Call this once, early, before the first network request is made.
  static Future<void> applyStoredOverride() async {
    final saved = await getOverride();
    if (saved != null && saved.isNotEmpty) {
      dioClient.options.baseUrl = saved;
    }
  }

  static Future<String?> getOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Persists [url] and immediately points the live [dioClient] at it.
  /// Pass null/empty to clear the override and fall back to [AppConfig].
  static Future<void> setOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_key);
      dioClient.options.baseUrl = AppConfig.apiBaseUrl;
    } else {
      await prefs.setString(_key, trimmed);
      dioClient.options.baseUrl = trimmed;
    }
  }

  /// Hits GET /api/health with a short timeout so Settings can show a clear
  /// "connected" / "unreachable" result instead of a vague AI-chat error
  /// three screens later.
  static Future<ServerTestResult> testConnection([String? urlOverride]) async {
    final base = urlOverride?.trim().isNotEmpty == true
        ? urlOverride!.trim()
        : dioClient.options.baseUrl;
    try {
      final res = await dioClient.get(
        '$base/api/health',
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      if (res.statusCode == 200) {
        return const ServerTestResult(ok: true, message: 'Connected — server is reachable.');
      }
      return ServerTestResult(ok: false, message: 'Server responded with ${res.statusCode}.');
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ServerTestResult(ok: false, message: 'Timed out — server unreachable at this address.');
        case DioExceptionType.connectionError:
          return const ServerTestResult(ok: false, message: 'Connection refused — check the URL, that the server is running, and that this device can reach it.');
        default:
          return ServerTestResult(ok: false, message: e.message ?? 'Connection failed.');
      }
    } catch (e) {
      return ServerTestResult(ok: false, message: e.toString());
    }
  }
}

class ServerTestResult {
  final bool ok;
  final String message;
  const ServerTestResult({required this.ok, required this.message});
}
