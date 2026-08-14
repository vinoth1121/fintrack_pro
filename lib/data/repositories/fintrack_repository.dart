import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../models/models.dart';
import 'auth_repository.dart';
import '../../core/storage/token_storage.dart';

/// Repository for all CRUD API calls (server-synced data).
class FinTrackRepository {
  const FinTrackRepository._();

  // ── Categories ──────────────────────────────────────────
  static Future<List<Category>> fetchCategories() async {
    final res = await dioClient.get(ApiEndpoints.categories);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['categories'] as List;
    return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Accounts ────────────────────────────────────────────
  static Future<List<Account>> fetchAccounts() async {
    final res = await dioClient.get(ApiEndpoints.accounts);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['accounts'] as List;
    return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Transactions ────────────────────────────────────────
  static Future<List<Transaction>> fetchTransactions({int limit = 200}) async {
    final res = await dioClient.get(ApiEndpoints.transactions, queryParameters: {'limit': limit});
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['items'] as List? ?? data['transactions'] as List? ?? [];
    return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Transaction> createTransaction(Transaction tx) async {
    final res = await dioClient.post(ApiEndpoints.transactions, data: {
      'type': tx.type.name,
      'amount': tx.amount,
      'categoryId': tx.categoryId,
      'accountId': tx.account,
      'date': tx.date.toIso8601String(),
      'note': tx.note,
      'merchant': tx.merchant,
      'recurring': tx.recurring,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Create failed');
    return Transaction.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  static Future<Transaction> updateTransaction(String id, Transaction tx) async {
    final res = await dioClient.patch('${ApiEndpoints.transactions}/$id', data: {
      'type': tx.type.name,
      'amount': tx.amount,
      'categoryId': tx.categoryId,
      'accountId': tx.account,
      'date': tx.date.toIso8601String(),
      'note': tx.note,
      'merchant': tx.merchant,
      'recurring': tx.recurring,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Update failed');
    return Transaction.fromJson(data['transaction'] as Map<String, dynamic>);
  }

  static Future<void> deleteTransaction(String id) async {
    await dioClient.delete('${ApiEndpoints.transactions}/$id');
  }

  // ── Budgets ─────────────────────────────────────────────
  static Future<List<Budget>> fetchBudgets() async {
    final res = await dioClient.get(ApiEndpoints.budgets);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['budgets'] as List;
    return list.map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Budget> createBudget(Budget b) async {
    final res = await dioClient.post(ApiEndpoints.budgets, data: {
      'categoryId': b.categoryId,
      'limit': b.limit,
      'period': b.period.name,
      'rollover': b.rollover,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Create failed');
    return Budget.fromJson(data['budget'] as Map<String, dynamic>);
  }

  static Future<void> deleteBudget(String id) async {
    await dioClient.delete('${ApiEndpoints.budgets}/$id');
  }

  // ── Goals ───────────────────────────────────────────────
  static Future<List<SavingsGoal>> fetchGoals() async {
    final res = await dioClient.get(ApiEndpoints.goals);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['goals'] as List;
    return list.map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<SavingsGoal> createGoal(SavingsGoal g) async {
    final res = await dioClient.post(ApiEndpoints.goals, data: {
      'name': g.name,
      'target': g.target,
      'saved': g.saved,
      'deadline': g.deadline?.toIso8601String(),
      'icon': g.icon,
      'color': g.color,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Create failed');
    return SavingsGoal.fromJson(data['goal'] as Map<String, dynamic>);
  }

  static Future<void> updateGoal(String id, SavingsGoal g) async {
    await dioClient.patch('${ApiEndpoints.goals}/$id', data: {
      'name': g.name,
      'target': g.target,
      'saved': g.saved,
      'deadline': g.deadline?.toIso8601String(),
    },);
  }

  static Future<void> deleteGoal(String id) async {
    await dioClient.delete('${ApiEndpoints.goals}/$id');
  }

  static Future<SavingsGoal> contributeGoal(String id, double amount) async {
    final res = await dioClient.post('${ApiEndpoints.goals}/$id/contribute', data: {
      'amount': amount,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Contribute failed');
    return SavingsGoal.fromJson(data['goal'] as Map<String, dynamic>);
  }

  // ── Subscriptions ───────────────────────────────────────
  static Future<List<Subscription>> fetchSubscriptions() async {
    final res = await dioClient.get(ApiEndpoints.subscriptions);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['subscriptions'] as List;
    return list.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Subscription> createSubscription(Subscription s) async {
    final res = await dioClient.post(ApiEndpoints.subscriptions, data: {
      'name': s.name,
      'amount': s.amount,
      'cycle': s.cycle,
      'nextBilling': s.nextBilling.toIso8601String(),
      'category': s.category,
      'icon': s.icon,
      'color': s.color,
      'active': s.active,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Create failed');
    return Subscription.fromJson(data['subscription'] as Map<String, dynamic>);
  }

  static Future<void> updateSubscription(String id, Subscription s) async {
    await dioClient.patch('${ApiEndpoints.subscriptions}/$id', data: {
      'active': s.active,
      'amount': s.amount,
      'name': s.name,
    },);
  }

  static Future<void> deleteSubscription(String id) async {
    await dioClient.delete('${ApiEndpoints.subscriptions}/$id');
  }

  // ── Notes ───────────────────────────────────────────────
  static Future<List<Note>> fetchNotes() async {
    final res = await dioClient.get(ApiEndpoints.notes);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['notes'] as List;
    return list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Note> createNote(Note n) async {
    final res = await dioClient.post(ApiEndpoints.notes, data: {
      'title': n.title,
      'body': n.body,
      'color': n.color,
      'pinned': n.pinned,
      'tags': n.tags,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Create failed');
    return Note.fromJson(data['note'] as Map<String, dynamic>);
  }

  static Future<void> updateNote(String id, Note n) async {
    await dioClient.patch('${ApiEndpoints.notes}/$id', data: {
      'title': n.title,
      'body': n.body,
      'color': n.color,
      'pinned': n.pinned,
      'tags': n.tags,
    },);
  }

  static Future<void> deleteNote(String id) async {
    await dioClient.delete('${ApiEndpoints.notes}/$id');
  }

  // ── Notifications ───────────────────────────────────────
  static Future<List<AppNotification>> fetchNotifications() async {
    final res = await dioClient.get(ApiEndpoints.notifications);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['notifications'] as List;
    return list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> markNotificationRead(String id) async {
    await dioClient.patch('${ApiEndpoints.notifications}/$id', data: {'read': true});
  }

  static Future<void> markAllNotificationsRead() async {
    await dioClient.post('${ApiEndpoints.notifications}/read-all');
  }

  static Future<void> pushNotification(AppNotification n) async {
    await dioClient.post(ApiEndpoints.notifications, data: {
      'title': n.title,
      'body': n.body,
      'kind': n.kind.name,
      'read': n.read,
      'action': n.action != null ? {'label': n.action!.label, 'view': n.action!.view} : null,
    },);
  }

  // ── Seed ────────────────────────────────────────────────
  static Future<Map<String, int>> seedDemoData() async {
    final res = await dioClient.post(ApiEndpoints.seed);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Seed failed');
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    return summary.map((k, v) => MapEntry(k, v as int));
  }

  static Future<AuthResult> registerDev({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await dioClient.post(ApiEndpoints.authRegister, data: {
      'fullName': fullName,
      'email': email,
      'password': password,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Registration failed');
    final user = data['user'] != null
        ? AuthUser.fromJson(data['user'] as Map<String, dynamic>)
        : AuthUser(
            id: '',
            name: data['fullName'] as String? ?? fullName,
            email: data['email'] as String? ?? email,
            emailVerified: false,
            avatarColor: '#6C5CE7',
            baseCurrency: 'USD',
            monthlyIncomeGoal: 120000,
          );
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      userId: user.id, email: user.email, name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      otp: data['otp'] as String?,
      message: data['message'] as String?,
    );
  }

  static Future<AuthResult> verifyEmailDev(String email) async {
    final res = await dioClient.post(ApiEndpoints.authVerifyEmailDev, data: {'email': email});
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Verification failed');
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.saveSession(
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      userId: user.id, email: user.email, name: user.name,
    );
    return AuthResult(
      user: user,
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
    );
  }

  // ── Profile ─────────────────────────────────────────────
  static Future<UserProfile> updateProfile(UserProfile patch) async {
    final res = await dioClient.patch(ApiEndpoints.authMe, data: {
      'name': patch.name,
      'avatarColor': patch.avatarColor,
      'baseCurrency': patch.baseCurrency,
      'monthlyIncomeGoal': patch.monthlyIncomeGoal,
    },);
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception('Update failed');
    final u = data['user'] as Map<String, dynamic>;
    return UserProfile(
      name: u['name'] as String,
      email: u['email'] as String,
      avatarColor: u['avatarColor'] as String,
      baseCurrency: u['baseCurrency'] as String,
      monthlyIncomeGoal: (u['monthlyIncomeGoal'] as num).toDouble(),
    );
  }

  // ── Family ──────────────────────────────────────────────
  static Future<List<FamilyMemberDto>> fetchFamilyMembers() async {
    final res = await dioClient.get('${ApiEndpoints.family}/members');
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) return [];
    final list = data['members'] as List? ?? [];
    return list.map((e) => FamilyMemberDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Throws an [Exception] with the server's real error message on failure
  /// (e.g. "User not found with this email", "Member already added") so the
  /// UI can show the real reason instead of a generic toast.
  static Future<FamilyMemberDto> inviteFamilyMember({
    required String email,
    required String role,
  }) async {
    try {
      final res = await dioClient.post('${ApiEndpoints.family}/members', data: {
        'email': email,
        'role': role,
      },);
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true) throw Exception(data['error'] as String? ?? 'Invite failed');
      return FamilyMemberDto.fromJson(data['member'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final serverMsg = (e.response?.data is Map)
          ? (e.response!.data as Map)['error'] as String?
          : null;
      throw Exception(serverMsg ?? e.message ?? 'Invite failed');
    }
  }

  static Future<void> removeFamilyMember(String id) async {
    await dioClient.delete('${ApiEndpoints.family}/members/$id');
  }
}

/// A family member as returned by the backend (joined with the `users` table).
class FamilyMemberDto {
  final String id;
  final String memberId;
  final String name;
  final String email;
  final String role;

  const FamilyMemberDto({
    required this.id,
    required this.memberId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory FamilyMemberDto.fromJson(Map<String, dynamic> j) => FamilyMemberDto(
    id: (j['id'] ?? '').toString(),
    memberId: (j['member_id'] ?? '').toString(),
    name: (j['name'] ?? j['member_name'] ?? j['email'] ?? 'Member').toString(),
    email: (j['email'] ?? '').toString(),
    role: (j['role'] ?? 'member').toString(),
  );
}
