import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/models/models.dart';
import '../data/repositories/fintrack_repository.dart';
import 'fintrack_provider.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class FamilyMember {
  final String id;
  final String name;
  final String email;
  final String role;
  final String color;
  final double spend;
  final double budget;
  final bool isYou;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.color,
    this.spend = 0,
    this.budget = 0,
    this.isYou = false,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> j, {bool isYou = false}) {
    return FamilyMember(
      id: (j['id'] ?? j['member_id'] ?? '').toString(),
      name: (j['member_name'] ?? j['name'] ?? j['full_name'] ?? 'Unknown').toString(),
      email: (j['email'] ?? '').toString(),
      role: (j['role'] ?? 'member').toString(),
      color: j['avatar_color']?.toString() ?? '#6C5CE7',
      spend: (j['spend'] as num?)?.toDouble() ?? 0,
      budget: (j['budget'] as num?)?.toDouble() ?? 0,
      isYou: isYou,
    );
  }
}

class SharedBudget {
  final String name;
  final double spent;
  final double limit;
  final String color;

  const SharedBudget({
    required this.name,
    required this.spent,
    required this.limit,
    required this.color,
  });

  factory SharedBudget.fromJson(Map<String, dynamic> j) {
    return SharedBudget(
      name: (j['category_name'] ?? j['name'] ?? '').toString(),
      spent: (j['spent'] as num?)?.toDouble() ?? (j['amount'] as num?)?.toDouble() ?? 0,
      limit: (j['limit'] as num?)?.toDouble() ?? (j['budget'] as num?)?.toDouble() ?? 0,
      color: (j['color'] ?? '#00E676').toString(),
    );
  }
}

class FamilyState {
  final List<FamilyMember> members;
  final List<SharedBudget> sharedBudgets;
  final bool loading;
  final String? error;

  const FamilyState({
    this.members = const [],
    this.sharedBudgets = const [],
    this.loading = false,
    this.error,
  });

  FamilyState copyWith({
    List<FamilyMember>? members,
    List<SharedBudget>? sharedBudgets,
    bool? loading,
    String? error,
  }) {
    return FamilyState(
      members: members ?? this.members,
      sharedBudgets: sharedBudgets ?? this.sharedBudgets,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final familyProvider = StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  return FamilyNotifier();
});

class FamilyNotifier extends StateNotifier<FamilyState> {
  FinTrackRepository? _repo;

  FamilyNotifier() : super(const FamilyState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      _repo = FinTrackRepository(dioClient);
    } catch (_) {}
  }

  Future<void> fetchFamilyData() async {
    if (_repo == null) {
      _repo = FinTrackRepository(dioClient);
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final resp = await _repo!.getFamilyOverview();
      if (resp['ok'] == true) {
        final membersRaw = resp['members'] as List<dynamic>? ?? [];
        final profileEmail = _getProfileEmail();
        final members = membersRaw.map((m) {
          final member = FamilyMember.fromJson(m as Map<String, dynamic>);
          final isYou = member.email.isNotEmpty && member.email == profileEmail;
          return FamilyMember(
            id: member.id,
            name: isYou ? _getProfileName() : member.name,
            email: member.email,
            role: isYou ? 'admin' : member.role,
            color: isYou ? _getProfileColor() : member.color,
            spend: member.spend,
            budget: member.budget,
            isYou: isYou,
          );
        }).toList();

        // Parse shared transactions as shared budgets
        final sharedTx = resp['sharedTransactions'] as List<dynamic>? ?? [];
        final catSpend = <String, double>{};
        final catNames = <String, String>{};
        final catColors = <String, String>{};
        for (final tx in sharedTx) {
          final t = tx as Map<String, dynamic>;
          final catId = (t['category_id'] ?? t['categoryId'] ?? '').toString();
          final name = (t['category_name'] ?? t['categoryName'] ?? 'Shared').toString();
          final color = (t['color'] ?? '#00E676').toString();
          final amount = (t['amount'] as num?)?.toDouble() ?? 0;
          catSpend[catId] = (catSpend[catId] ?? 0) + amount;
          catNames[catId] = name;
          catColors[catId] = color;
        }
        final sharedBudgets = catSpend.entries.map((e) {
          return SharedBudget(
            name: catNames[e.key] ?? 'Shared',
            spent: e.value,
            limit: e.value * 1.5, // estimate budget as 1.5x current spend
            color: catColors[e.key] ?? '#00E676',
          );
        }).toList();

        state = state.copyWith(
          members: members,
          sharedBudgets: sharedBudgets,
          loading: false,
        );
      } else {
        state = state.copyWith(
          loading: false,
          error: resp['error']?.toString() ?? 'Failed to load family data',
        );
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> inviteMember(String email, String role) async {
    if (_repo == null) return;
    try {
      final resp = await _repo!.inviteFamilyMember({'email': email, 'role': role});
      if (resp['ok'] == true) {
        // Refresh the list after adding
        await fetchFamilyData();
      } else {
        state = state.copyWith(error: resp['error']?.toString() ?? 'Failed to invite member');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeMember(String id) async {
    if (_repo == null) return;
    try {
      await _repo!.removeFamilyMember(id);
      state = state.copyWith(
        members: state.members.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getProfileEmail() => _tryGetProfile()?.email ?? '';
  String _getProfileName() => _tryGetProfile()?.name ?? 'User';
  String _getProfileColor() => _tryGetProfile()?.avatarColor ?? '#6C5CE7';

  UserProfile? _tryGetProfile() {
    try {
      // Try to read profile from fintrack_provider's container
      return null; // fallback — will use defaults
    } catch (_) {
      return null;
    }
  }
}