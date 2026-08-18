import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/fintrack_repository.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class FamilyMember {
  final String id;
  final String memberId;
  final String name;
  final String email;
  final String role;
  final String color;
  final double spend;
  final double budget;
  final bool isYou;

  const FamilyMember({
    required this.id,
    this.memberId = '',
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

  /// Build from the backend DTO (joined with the `users` table).
  factory FamilyMember.fromDto(FamilyMemberDto dto) {
    return FamilyMember(
      id: dto.id,
      memberId: dto.memberId,
      name: dto.name,
      email: dto.email,
      role: dto.role,
      color: '#6C5CE7',
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
  FamilyNotifier() : super(const FamilyState()) {
    fetchFamilyData();
  }

  Future<void> fetchFamilyData() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final members = await FinTrackRepository.fetchFamilyMembers();
      state = state.copyWith(
        members: members.map((dto) => FamilyMember.fromDto(dto)).toList(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> inviteMember(String email, String role) async {
    try {
      final dto = await FinTrackRepository.inviteFamilyMember(email: email, role: role);
      state = state.copyWith(
        members: [...state.members, FamilyMember.fromDto(dto)],
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeMember(String id) async {
    try {
      await FinTrackRepository.removeFamilyMember(id);
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
}
