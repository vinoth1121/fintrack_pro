import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Real OS-level local push notifications for FinTrack Pro — budget alerts,
/// bill/subscription reminders, AI weekly summaries, and general app
/// notifications. Written from scratch (no dependency on the old in-app-only
/// notification list).
///
/// This is *local* notifications (fired by the device itself), which is the
/// right tool for on-device alerts like "you're over budget" or "bill due
/// tomorrow". It intentionally does not use Firebase Cloud Messaging — that
/// would require a backend push integration and API keys beyond this app's
/// current scope, and isn't needed for these use cases.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'fintrack_general';
  static const _channelName = 'FinTrack Pro Alerts';
  static const _channelDescription =
      'Budget alerts, bill reminders, savings milestones and AI insights';

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
      } catch (_) {
        // Fall back to UTC if the device timezone name isn't in the tz database
        // (common on some Android builds) — scheduled times will still fire,
        // just computed relative to UTC instead of the device's named zone.
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false, // we ask explicitly via requestPermission()
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(initSettings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (e, st) {
      // Non-fatal: a failing notification plugin must NEVER crash the app or a
      // screen. We log and continue; the UI degrades to "no OS notifications".
      debugPrint('[Notifications] init failed (non-fatal): $e');
      debugPrint('$st');
    }
  }

  /// Requests the OS notification permission. Required on Android 13+ (API
  /// 33+) and iOS; a no-op on older Android where it's granted by default.
  /// Returns true if permission is granted. Never throws.
  Future<bool> requestPermission() async {
    try {
      if (!_initialized) await init();
      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[Notifications] requestPermission failed: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await androidImpl?.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[Notifications] hasPermission failed: $e');
      return false;
    }
  }

  /// Fires a notification immediately. Never throws.
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_initialized) await init();
      final ok = await hasPermission();
      if (!ok) {
        debugPrint('[Notifications] permission not granted — skipping "$title"');
        return;
      }
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Notifications] showNow failed: $e');
    }
  }

  /// Schedules a one-off notification for a future [when]. Used for bill /
  /// subscription due-date reminders. Never throws.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_initialized) await init();
      final ok = await hasPermission();
      if (!ok) return;
      final scheduledDate = tz.TZDateTime.from(when, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Notifications] scheduleAt failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notifications] cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notifications] cancelAll failed: $e');
    }
  }
}
