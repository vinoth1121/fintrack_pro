import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/dio_client.dart';

const _kThemeModeKey = 'app_theme_mode';

// ─── Theme State (device-local — appropriate, since theme is a display
// preference not tied to financial data integrity) ───────────────────────────

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    state = switch (saved) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// ─── Biometric Toggle (server-persisted — affects auth security posture) ─────

class BiometricState extends Equatable {
  final bool isEnabled;
  final bool isLoading;

  const BiometricState({this.isEnabled = false, this.isLoading = false});

  BiometricState copyWith({bool? isEnabled, bool? isLoading}) {
    return BiometricState(isEnabled: isEnabled ?? this.isEnabled, isLoading: isLoading ?? this.isLoading);
  }

  @override
  List<Object?> get props => [isEnabled, isLoading];
}

class BiometricNotifier extends StateNotifier<BiometricState> {
  final Ref _ref;

  BiometricNotifier(this._ref) : super(const BiometricState()) {
    final user = _ref.read(authProvider).user;
    if (user != null) state = state.copyWith(isEnabled: user.isBiometricEnabled);
  }

  Future<void> toggle(bool enabled) async {
    final previous = state.isEnabled;
    state = state.copyWith(isEnabled: enabled, isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/users/me/biometric', data: {'enabled': enabled});

      final currentUser = _ref.read(authProvider).user;
      if (currentUser != null) {
        _ref.read(authProvider.notifier).updateUser(currentUser.copyWith(isBiometricEnabled: enabled));
      }
      state = state.copyWith(isLoading: false);
    } on DioException {
      // Revert optimistic update on failure
      state = state.copyWith(isEnabled: previous, isLoading: false);
    }
  }
}

final biometricProvider = StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier(ref);
});

// ─── Notification Preferences (device-local toggles for push categories) ─────

class NotificationPrefsState extends Equatable {
  final bool budgetAlerts;
  final bool billReminders;
  final bool goalMilestones;
  final bool aiInsights;

  const NotificationPrefsState({
    this.budgetAlerts = true,
    this.billReminders = true,
    this.goalMilestones = true,
    this.aiInsights = true,
  });

  NotificationPrefsState copyWith({
    bool? budgetAlerts,
    bool? billReminders,
    bool? goalMilestones,
    bool? aiInsights,
  }) {
    return NotificationPrefsState(
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      billReminders: billReminders ?? this.billReminders,
      goalMilestones: goalMilestones ?? this.goalMilestones,
      aiInsights: aiInsights ?? this.aiInsights,
    );
  }

  @override
  List<Object?> get props => [budgetAlerts, billReminders, goalMilestones, aiInsights];
}

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefsState> {
  NotificationPrefsNotifier() : super(const NotificationPrefsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationPrefsState(
      budgetAlerts: prefs.getBool('notif_budget_alerts') ?? true,
      billReminders: prefs.getBool('notif_bill_reminders') ?? true,
      goalMilestones: prefs.getBool('notif_goal_milestones') ?? true,
      aiInsights: prefs.getBool('notif_ai_insights') ?? true,
    );
  }

  Future<void> setBudgetAlerts(bool value) async {
    state = state.copyWith(budgetAlerts: value);
    (await SharedPreferences.getInstance()).setBool('notif_budget_alerts', value);
  }

  Future<void> setBillReminders(bool value) async {
    state = state.copyWith(billReminders: value);
    (await SharedPreferences.getInstance()).setBool('notif_bill_reminders', value);
  }

  Future<void> setGoalMilestones(bool value) async {
    state = state.copyWith(goalMilestones: value);
    (await SharedPreferences.getInstance()).setBool('notif_goal_milestones', value);
  }

  Future<void> setAiInsights(bool value) async {
    state = state.copyWith(aiInsights: value);
    (await SharedPreferences.getInstance()).setBool('notif_ai_insights', value);
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefsState>((ref) {
  return NotificationPrefsNotifier();
});
