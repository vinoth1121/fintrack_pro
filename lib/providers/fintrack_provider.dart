import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/formatters.dart';
import '../core/services/notification_service.dart';
import '../data/models/models.dart';
import '../data/seed/seed_data.dart';
import '../data/repositories/fintrack_repository.dart';

/// Locale codes supported by the app.
typedef AppLocale = String; // en | es | fr | de | hi | ta | ja

/// The full FinTrack application state — faithfully mirrors the web Zustand store.
class FinTrackState {
  final bool booted;
  final bool onboardingDone;
  final AppLocale locale;
  final String theme; // dark | light
  final UserProfile profile;
  final List<Category> categories;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<SavingsGoal> goals;
  final List<Subscription> subscriptions;
  final List<Note> notes;
  final List<AppNotification> notifications;
  final List<ChatMessage> chat;

  FinTrackState({
    this.booted = false,
    this.onboardingDone = false,
    this.locale = 'en',
    this.theme = 'dark',
    this.profile = defaultProfile,
    List<Category>? categories,
    List<Account>? accounts,
    this.transactions = const [],
    List<Budget>? budgets,
    List<SavingsGoal>? goals,
    List<Subscription>? subscriptions,
    List<Note>? notes,
    List<AppNotification>? notifications,
    this.chat = const [],
  })  : categories = categories ?? defaultCategories,
        accounts = accounts ?? defaultAccounts,
        budgets = budgets ?? defaultBudgets,
        goals = goals ?? defaultGoals,
        subscriptions = subscriptions ?? defaultSubscriptions,
        notes = notes ?? defaultNotes,
        notifications = notifications ?? defaultNotifications;

  FinTrackState copyWith({
    bool? booted, bool? onboardingDone, AppLocale? locale, String? theme,
    UserProfile? profile, List<Category>? categories, List<Account>? accounts,
    List<Transaction>? transactions, List<Budget>? budgets,
    List<SavingsGoal>? goals, List<Subscription>? subscriptions,
    List<Note>? notes, List<AppNotification>? notifications,
    List<ChatMessage>? chat,
  }) => FinTrackState(
    booted: booted ?? this.booted,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    locale: locale ?? this.locale,
    theme: theme ?? this.theme,
    profile: profile ?? this.profile,
    categories: categories ?? this.categories,
    accounts: accounts ?? this.accounts,
    transactions: transactions ?? this.transactions,
    budgets: budgets ?? this.budgets,
    goals: goals ?? this.goals,
    subscriptions: subscriptions ?? this.subscriptions,
    notes: notes ?? this.notes,
    notifications: notifications ?? this.notifications,
    chat: chat ?? this.chat,
  );

  Map<String, dynamic> toJson() => {
    'onboardingDone': onboardingDone, 'locale': locale, 'theme': theme,
    'profile': profile.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'budgets': budgets.map((b) => b.toJson()).toList(),
    'goals': goals.map((g) => g.toJson()).toList(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'notifications': notifications.map((n) => n.toJson()).toList(),
    'chat': chat.map((m) => m.toJson()).toList(),
  };

  factory FinTrackState.fromJson(Map<String, dynamic> j) {
    final base = FinTrackState();
    return base.copyWith(
      onboardingDone: j['onboardingDone'] as bool? ?? false,
      locale: j['locale'] as AppLocale? ?? 'en',
      theme: j['theme'] as String? ?? 'dark',
      profile: j['profile'] != null ? UserProfile.fromJson(j['profile']) : base.profile,
      categories: (j['categories'] as List?)?.map((e) => Category.fromJson(e)).toList() ?? base.categories,
      accounts: (j['accounts'] as List?)?.map((e) => Account.fromJson(e)).toList() ?? base.accounts,
      transactions: (j['transactions'] as List?)?.map((e) => Transaction.fromJson(e)).toList() ?? seedTransactions,
      budgets: (j['budgets'] as List?)?.map((e) => Budget.fromJson(e)).toList() ?? base.budgets,
      goals: (j['goals'] as List?)?.map((e) => SavingsGoal.fromJson(e)).toList() ?? base.goals,
      subscriptions: (j['subscriptions'] as List?)?.map((e) => Subscription.fromJson(e)).toList() ?? base.subscriptions,
      notes: (j['notes'] as List?)?.map((e) => Note.fromJson(e)).toList() ?? base.notes,
      notifications: (j['notifications'] as List?)?.map((e) => AppNotification.fromJson(e)).toList() ?? base.notifications,
      chat: (j['chat'] as List?)?.map((e) => ChatMessage.fromJson(e)).toList() ?? const [],
    );
  }
}

class FinTrackNotifier extends StateNotifier<FinTrackState> {
  FinTrackNotifier() : super(FinTrackState(transactions: seedTransactions)) {
    _load();
  }

  static const _key = 'fintrack_pro_flutter_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = FinTrackState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  // UI state
  void setBooted(bool v) { state = state.copyWith(booted: v); }
  void setOnboardingDone(bool v) { state = state.copyWith(onboardingDone: v); _persist(); }
  void setLocale(AppLocale l) { state = state.copyWith(locale: l); _persist(); }
  void setTheme(String t) { state = state.copyWith(theme: t); _persist(); }
  void toggleTheme() { state = state.copyWith(theme: state.theme == 'dark' ? 'light' : 'dark'); _persist(); }

  // ── Sync-error surface for the UI (e.g. show a "couldn't save to server" toast) ──
  String? lastSyncError;
  void _syncFailed(String op, Object e) {
    lastSyncError = '$op failed to save to the server: $e';
    // ignore: avoid_print
    print('[FinTrack sync] $lastSyncError');
  }

  // Transactions
  Future<void> addTransaction(Transaction t) async {
    // Optimistic local update so the UI feels instant.
    state = state.copyWith(transactions: [t, ...state.transactions]);
    _persist();
    try {
      final saved = await FinTrackRepository.createTransaction(t);
      state = state.copyWith(
        transactions: state.transactions.map((x) => x.id == t.id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Add transaction', e);
    }
  }
  Future<void> updateTransaction(String id, Transaction patch) async {
    state = state.copyWith(
      transactions: state.transactions.map((t) => t.id == id ? patch : t).toList(),
    );
    _persist();
    try {
      final saved = await FinTrackRepository.updateTransaction(id, patch);
      state = state.copyWith(
        transactions: state.transactions.map((x) => x.id == id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Update transaction', e);
    }
  }
  Future<void> deleteTransaction(String id) async {
    final backup = state.transactions;
    state = state.copyWith(transactions: state.transactions.where((t) => t.id != id).toList());
    _persist();
    try {
      await FinTrackRepository.deleteTransaction(id);
    } catch (e) {
      _syncFailed('Delete transaction', e);
      // Roll back so we don't silently lose data the server still has.
      state = state.copyWith(transactions: backup);
      _persist();
    }
  }

  // Budgets
  Future<void> addBudget(Budget b) async {
    state = state.copyWith(budgets: [...state.budgets, b]);
    _persist();
    try {
      final saved = await FinTrackRepository.createBudget(b);
      state = state.copyWith(
        budgets: state.budgets.map((x) => x.id == b.id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Add budget', e);
    }
  }
  Future<void> deleteBudget(String id) async {
    final backup = state.budgets;
    state = state.copyWith(budgets: state.budgets.where((b) => b.id != id).toList());
    _persist();
    try {
      await FinTrackRepository.deleteBudget(id);
    } catch (e) {
      _syncFailed('Delete budget', e);
      state = state.copyWith(budgets: backup);
      _persist();
    }
  }

  // Goals
  Future<void> addGoal(SavingsGoal g) async {
    state = state.copyWith(goals: [...state.goals, g]);
    _persist();
    try {
      final saved = await FinTrackRepository.createGoal(g);
      state = state.copyWith(
        goals: state.goals.map((x) => x.id == g.id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Add goal', e);
    }
  }
  Future<void> contributeGoal(String id, double amount) async {
    state = state.copyWith(
      goals: state.goals.map((g) =>
        g.id == id ? g.copyWith(saved: (g.saved + amount).clamp(0, double.infinity)) : g,).toList(),
    );
    _persist();
    try {
      final saved = await FinTrackRepository.contributeGoal(id, amount);
      state = state.copyWith(
        goals: state.goals.map((x) => x.id == id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Contribute to goal', e);
    }
  }
  Future<void> deleteGoal(String id) async {
    final backup = state.goals;
    state = state.copyWith(goals: state.goals.where((g) => g.id != id).toList());
    _persist();
    try {
      await FinTrackRepository.deleteGoal(id);
    } catch (e) {
      _syncFailed('Delete goal', e);
      state = state.copyWith(goals: backup);
      _persist();
    }
  }

  // Subscriptions
  Future<void> addSubscription(Subscription s) async {
    state = state.copyWith(subscriptions: [s, ...state.subscriptions]);
    _persist();
    try {
      final saved = await FinTrackRepository.createSubscription(s);
      state = state.copyWith(
        subscriptions: state.subscriptions.map((x) => x.id == s.id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Add subscription', e);
    }
  }
  Future<void> updateSubscription(String id, Subscription patch) async {
    state = state.copyWith(
      subscriptions: state.subscriptions.map((s) => s.id == id ? s.copyWith(active: patch.active) : s).toList(),
    );
    _persist();
    try {
      await FinTrackRepository.updateSubscription(id, patch);
    } catch (e) {
      _syncFailed('Update subscription', e);
    }
  }
  Future<void> deleteSubscription(String id) async {
    final backup = state.subscriptions;
    state = state.copyWith(subscriptions: state.subscriptions.where((s) => s.id != id).toList());
    _persist();
    try {
      await FinTrackRepository.deleteSubscription(id);
    } catch (e) {
      _syncFailed('Delete subscription', e);
      state = state.copyWith(subscriptions: backup);
      _persist();
    }
  }

  // Notes
  Future<void> addNote(Note n) async {
    state = state.copyWith(notes: [n, ...state.notes]);
    _persist();
    try {
      final saved = await FinTrackRepository.createNote(n);
      state = state.copyWith(
        notes: state.notes.map((x) => x.id == n.id ? saved : x).toList(),
      );
      _persist();
    } catch (e) {
      _syncFailed('Add note', e);
    }
  }
  Future<void> updateNote(String id, Note patch) async {
    state = state.copyWith(
      notes: state.notes.map((n) => n.id == id ? n.copyWith(title: patch.title, body: patch.body, color: patch.color, pinned: patch.pinned, tags: patch.tags) : n).toList(),
    );
    _persist();
    try {
      await FinTrackRepository.updateNote(id, patch);
    } catch (e) {
      _syncFailed('Update note', e);
    }
  }
  Future<void> deleteNote(String id) async {
    final backup = state.notes;
    state = state.copyWith(notes: state.notes.where((n) => n.id != id).toList());
    _persist();
    try {
      await FinTrackRepository.deleteNote(id);
    } catch (e) {
      _syncFailed('Delete note', e);
      state = state.copyWith(notes: backup);
      _persist();
    }
  }

  // Notifications
  Future<void> markNotificationRead(String id) async {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.id == id ? n.copyWith(read: true) : n).toList(),
    );
    _persist();
    try {
      await FinTrackRepository.markNotificationRead(id);
    } catch (e) {
      _syncFailed('Mark notification read', e);
    }
  }
  Future<void> markAllRead() async {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(read: true)).toList(),
    );
    _persist();
    try {
      await FinTrackRepository.markAllNotificationsRead();
    } catch (e) {
      _syncFailed('Mark all notifications read', e);
    }
  }
  Future<void> pushNotification(AppNotification n) async {
    state = state.copyWith(notifications: [n, ...state.notifications]);
    _persist();
    // Fire the real OS-level notification. This is fire-and-forget and never
    // blocks the in-app state update — if the OS denies permission or the
    // service isn't initialized yet, the notification simply won't show,
    // but it still appears correctly in the in-app list above.
    unawaited(NotificationService.instance.showNow(title: n.title, body: n.body));
    try {
      await FinTrackRepository.pushNotification(n);
    } catch (e) {
      _syncFailed('Push notification', e);
    }
  }

  // Chat
  void addChatMessage(ChatMessage m) { state = state.copyWith(chat: [...state.chat, m]); _persist(); }
  void clearChat() { state = state.copyWith(chat: const []); _persist(); }

  // Profile
  void updateProfile(UserProfile patch) { state = state.copyWith(profile: patch); _persist(); }

  // Reset
  void resetAll() {
    state = FinTrackState(transactions: seedTransactions, onboardingDone: true, booted: true);
    _persist();
  }

  // Restore from backup
  void restoreBackup(FinTrackState data) {
    state = data;
    _persist();
  }

  /// Fetch all data from the server (called after login).
  Future<void> syncFromServer() async {
    try {
      final results = await Future.wait([
        FinTrackRepository.fetchCategories(),
        FinTrackRepository.fetchAccounts(),
        FinTrackRepository.fetchTransactions(),
        FinTrackRepository.fetchBudgets(),
        FinTrackRepository.fetchGoals(),
        FinTrackRepository.fetchSubscriptions(),
        FinTrackRepository.fetchNotes(),
        FinTrackRepository.fetchNotifications(),
      ]);
      state = state.copyWith(
        categories: results[0] as List<Category>,
        accounts: results[1] as List<Account>,
        transactions: results[2] as List<Transaction>,
        budgets: results[3] as List<Budget>,
        goals: results[4] as List<SavingsGoal>,
        subscriptions: results[5] as List<Subscription>,
        notes: results[6] as List<Note>,
        notifications: results[7] as List<AppNotification>,
      );
      _persist();
    } catch (_) {
      // Server unavailable — keep local data
    }
  }

  /// Seed demo data on the server, then sync.
  Future<void> seedAndSync() async {
    try {
      await FinTrackRepository.seedDemoData();
      await syncFromServer();
    } catch (_) {}
  }
}

final fintrackProvider = StateNotifierProvider<FinTrackNotifier, FinTrackState>(
  (ref) => FinTrackNotifier(),
);

/// Derived analytics (mirrors useDerived from the web app).
class DerivedData {
  final double monthExpenses;
  final double monthIncome;
  final double totalExpenses;
  final double totalIncome;
  final double netBalance;
  final double savingsRate;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<SparkPoint> sparkline;
  final List<BudgetUsage> budgetUsage;
  final int goalsOnTrack;
  final int goalsTotal;
  final double expenseDelta;
  final double incomeDelta;
  final List<TrendPoint> trend;
  final int budgetsOver;

  const DerivedData({
    required this.monthExpenses, required this.monthIncome,
    required this.totalExpenses, required this.totalIncome,
    required this.netBalance, required this.savingsRate,
    required this.categoryBreakdown, required this.sparkline,
    required this.budgetUsage, required this.goalsOnTrack,
    required this.goalsTotal, required this.expenseDelta,
    required this.incomeDelta, required this.trend, required this.budgetsOver,
  });
}

class CategoryBreakdown {
  final String categoryId, name, color, icon;
  final double amount;
  final int pct;
  const CategoryBreakdown({required this.categoryId, required this.name, required this.color, required this.icon, required this.amount, required this.pct});
}

class SparkPoint { final DateTime date; final String label; final double expense; const SparkPoint(this.date, this.label, this.expense); }
class TrendPoint { final String month; final double income; final double expense; const TrendPoint(this.month, this.income, this.expense); }
class BudgetUsage {
  final String budgetId, categoryId, categoryName, color, icon;
  final double limit, spent, remaining;
  final int pct; final bool over;
  const BudgetUsage({required this.budgetId, required this.categoryId, required this.categoryName, required this.color, required this.icon, required this.limit, required this.spent, required this.remaining, required this.pct, required this.over});
}

final derivedProvider = Provider<DerivedData>((ref) {
  final s = ref.watch(fintrackProvider);
  final now = DateTime.now();
  final monthTx = s.transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
  final monthExpenses = monthTx.where((t) => t.type == TxType.expense).fold(0.0, (a, t) => a + t.amount);
  final monthIncome = monthTx.where((t) => t.type == TxType.income).fold(0.0, (a, t) => a + t.amount);
  final totalExpenses = s.transactions.where((t) => t.type == TxType.expense).fold(0.0, (a, t) => a + t.amount);
  final totalIncome = s.transactions.where((t) => t.type == TxType.income).fold(0.0, (a, t) => a + t.amount);
  final netBalance = s.accounts.fold(0.0, (a, x) => a + x.balance);
  final savingsRate = monthIncome > 0 ? (monthIncome - monthExpenses) / monthIncome : 0.0;

  final catMap = <String, double>{};
  for (final t in monthTx) {
    if (t.type != TxType.expense) continue;
    catMap[t.categoryId] = (catMap[t.categoryId] ?? 0) + t.amount;
  }
  final breakdown = catMap.entries.map((e) {
    final c = s.categories.firstWhere((x) => x.id == e.key, orElse: () => s.categories.last);
    return CategoryBreakdown(categoryId: e.key, name: c.name, color: c.color, icon: c.icon, amount: e.value, pct: (e.value / (monthExpenses > 0 ? monthExpenses : 1) * 100).round().clamp(0, 100));
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  final spark = lastNDays(7).map((d) {
    final e = s.transactions.where((t) =>
      t.type == TxType.expense &&
      t.date.year == d.year && t.date.month == d.month && t.date.day == d.day,
    ).fold(0.0, (a, t) => a + t.amount);
    return SparkPoint(d, formatWeekday(d), e);
  }).toList();

  final usage = s.budgets.map((b) {
    final cat = s.categories.firstWhere((c) => c.id == b.categoryId, orElse: () => s.categories.last);
    final spent = monthTx.where((t) => t.type == TxType.expense && t.categoryId == b.categoryId).fold(0.0, (a, t) => a + t.amount);
    return BudgetUsage(
      budgetId: b.id, categoryId: b.categoryId, categoryName: cat.name,
      color: cat.color, icon: cat.icon, limit: b.limit, spent: spent,
      remaining: b.limit - spent, pct: (spent / b.limit * 100).round().clamp(0, 100),
      over: spent > b.limit,
    );
  }).toList();

  final prevMonth = DateTime(now.year, now.month - 1, 1);
  final prevTx = s.transactions.where((t) => t.date.year == prevMonth.year && t.date.month == prevMonth.month).toList();
  final prevExp = prevTx.where((t) => t.type == TxType.expense).fold(0.0, (a, t) => a + t.amount);
  final prevInc = prevTx.where((t) => t.type == TxType.income).fold(0.0, (a, t) => a + t.amount);
  final expenseDelta = prevExp > 0 ? ((monthExpenses - prevExp) / prevExp * 100) : 0.0;
  final incomeDelta = prevInc > 0 ? ((monthIncome - prevInc) / prevInc * 100) : 0.0;

  final trend = <TrendPoint>[];
  for (var i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final tx = s.transactions.where((t) => t.date.year == d.year && t.date.month == d.month).toList();
    trend.add(TrendPoint(
      const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1],
      tx.where((t) => t.type == TxType.income).fold(0.0, (a, t) => a + t.amount),
      tx.where((t) => t.type == TxType.expense).fold(0.0, (a, t) => a + t.amount),
    ),);
  }

  final budgetsOver = usage.where((u) => u.over).length;
  final goalsOnTrack = s.goals.where((g) {
    final p = (g.saved / g.target * 100).round();
    if (g.deadline == null) return p >= 50;
    final daysLeft = g.deadline!.difference(now).inDays;
    return daysLeft > 0 && (g.target - g.saved) / daysLeft <= g.target / 300;
  }).length;

  return DerivedData(
    monthExpenses: monthExpenses, monthIncome: monthIncome,
    totalExpenses: totalExpenses, totalIncome: totalIncome,
    netBalance: netBalance, savingsRate: savingsRate,
    categoryBreakdown: breakdown, sparkline: spark, budgetUsage: usage,
    goalsOnTrack: goalsOnTrack, goalsTotal: s.goals.length,
    expenseDelta: expenseDelta, incomeDelta: incomeDelta,
    trend: trend, budgetsOver: budgetsOver,
  );
});
