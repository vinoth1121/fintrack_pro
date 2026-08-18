import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/server_config.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.applyStoredOverride();
  try {
    await NotificationService.instance.init();
  } catch (e) {
    // Non-fatal: the app must still launch even if OS notifications are unavailable.
    debugPrint('[main] NotificationService.init failed (non-fatal): $e');
  }
  runApp(const ProviderScope(child: FinTrackApp()));
}
