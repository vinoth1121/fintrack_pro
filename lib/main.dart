import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/server_config.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.applyStoredOverride();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: FinTrackApp()));
}
