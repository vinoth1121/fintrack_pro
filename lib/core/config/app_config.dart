import 'package:flutter/foundation.dart';

/// Central configuration for FinTrack Pro.
class AppConfig {
  AppConfig._();

  /// Base URL of the FinTrack Pro backend.
  /// - Android emulator → host machine: `http://10.0.2.2:3000`
  /// - Physical device → your LAN IP: `http://192.168.x.x:3000`
  /// - Production → your deployed API URL.
  ///
  /// Override at build time with:
  ///   `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000`
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://localhost:3000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  /// App version (kept in sync with pubspec.yaml).
  static const String appVersion = '1.0.0';

  /// App name.
  static const String appName = 'FinTrack Pro';

  /// Default base currency.
  static const String defaultCurrency = 'INR';
}
