import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Riverpod provider that exposes the singleton [dioClient].
/// Import this provider from any repository/datasource that needs the API.
final dioProvider = Provider<Dio>((ref) => dioClient);

/// Centralized Dio HTTP client + API endpoint paths.
/// All AI + auth + CRUD requests go through the FinTrack Pro backend.
final Dio dioClient = Dio(BaseOptions(
  baseUrl: AppConfig.apiBaseUrl, // Ensure this matches backend URL
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 60),
  sendTimeout: const Duration(seconds: 30),
  headers: {'Content-Type': 'application/json'},
  responseType: ResponseType.json,
),)
  ..interceptors.add(AuthInterceptor())
  ..interceptors.add(LogInterceptor(requestBody: false, responseBody: false, error: true));

/// Interceptor that auto-attaches the JWT Bearer token + auto-refreshes on 401.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Don't attach token to auth endpoints (prevents 401 on public routes)
    final isAuthEndpoint = options.path.contains('/api/auth/login') ||
        options.path.contains('/api/auth/register') ||
        options.path.contains('/api/auth/refresh') ||
        options.path.contains('/api/auth/otp') ||
        options.path.contains('/api/auth/forgot-password') ||
        options.path.contains('/api/auth/reset-password') ||
        options.path.contains('/api/auth/verify-email-dev') ||
        options.path.contains('/api/auth/me') && await TokenStorage.getAccessToken() == null;
    if (!isAuthEndpoint) {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final refreshed = await _tryRefresh(err.requestOptions);
      if (refreshed) {
        handler.resolve(await dioClient.fetch(err.requestOptions));
        return;
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh(RequestOptions requestOptions) async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      // Use a separate Dio instance to avoid interceptor recursion
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ),);
      final res = await refreshDio.post('/api/auth/refresh', data: {
        'refreshToken': refreshToken,
      },);
      if (res.statusCode == 200 && res.data['ok'] == true) {
        final newAccess = res.data['accessToken'] as String;
        final newRefresh = res.data['refreshToken'] as String;
        await TokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
        requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        return true;
      }
    } catch (_) {
      // Refresh failed — clear session, user must log in again
      await TokenStorage.clearAll();
    }
    return false;
  }
}

/// API endpoint paths (the FinTrack Pro backend routes).
class ApiEndpoints {
  ApiEndpoints._();
  // Auth
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authMe = '/api/auth/me';
  static const String authOtpSend = '/api/auth/otp/send';
  static const String authOtpVerify = '/api/auth/otp/verify';
  static const String authVerifyEmailDev = '/api/auth/verify-email-dev';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authResetPassword = '/api/auth/reset-password';
  static const String authPhoneSend = '/api/auth/phone/send';
  static const String authPhoneVerify = '/api/auth/phone/verify';
  static const String authBiometric = '/api/auth/biometric';
  static const String authBiometricVerify = '/api/auth/biometric/verify';
  static const String authPasskey = '/api/auth/passkey/generate';
  // CRUD
  static const String transactions = '/api/transactions';
  static const String budgets = '/api/budgets';
  static const String goals = '/api/goals';
  static const String subscriptions = '/api/subscriptions';
  static const String notes = '/api/notes';
  static const String categories = '/api/categories';
  static const String accounts = '/api/accounts';
  static const String notifications = '/api/notifications';
  static const String seed = '/api/seed';
  // AI
  static const String aiChat = '/api/ai/chat';
  static const String aiReceipt = '/api/ai/receipt';
  static const String aiVoice = '/api/ai/voice';
  static const String aiInsights = '/api/ai/insights';
  static const String aiWeeklySummary = '/api/ai/weekly-summary';
  // Finance Tools
  static const String family = '/api/family';
  static const String exports = '/api/exports';
  static const String calculator = '/api/calculator';
  static const String calculatorSavings = '/api/calculator/savings-compound';
  static const String calculatorLoan = '/api/calculator/loan-emi';
  static const String calculatorSplitBill = '/api/calculator/split-bill';
  static const String calculatorFire = '/api/calculator/fire';
  static const String currencyLive = '/api/currency/live';
  static const String exportsCsv = '/api/exports/transactions/csv';
  static const String exportsJson = '/api/exports/transactions/json';
  static const String exportsAll = '/api/exports/all';
  static const String exportsSummary = '/api/exports/summary';
}
