import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/fintrack_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// Family Accounts screen — faithful Flutter port of family.tsx, now backed
/// by the real /api/family endpoints instead of hardcoded sample people.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  List<FamilyMemberDto> _remoteMembers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final members = await FinTrackRepository.fetchFamilyMembers();
      if (!mounted) return;
      setState(() { _remoteMembers = members; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openInviteDialog(BuildContext context, AppT t) {
    showDialog<void>(
      context: context,
      builder: (_) => _InviteDialog(t: t, onInvited: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final d = ref.watch(derivedProvider);
    final l = context.lumina;
    final currency = s.profile.baseCurrency;
    final totalFamilyBalance =
        (s.accounts).fold(0.0, (a, x) => a + x.balance);

    final members = <_FamilyMember>[
      _FamilyMember(
        id: 'you',
        name: s.profile.name,
        role: 'admin',
        color: s.profile.avatarColor,
        spend: d.monthExpenses,
        budget: 80000,
        isYou: true,
      ),
      // Real members invited via /api/family/members. Per-member spend/budget
      // breakdowns require each member's own transactions and aren't exposed
      // by the backend yet — shown as 0 until that endpoint exists.
      ..._remoteMembers.map((m) => _FamilyMember(
        id: m.id,
        name: m.name,
        role: m.role,
        color: '#7C6CFF',
        spend: 0,
        budget: 0,
      ),),
    ];

    // NOTE: The backend has no "shared budget" concept yet (only per-user
    // budgets). Until that's added server-side, this mirrors the current
    // user's own budgets rather than showing fabricated family data.
    final sharedBudgets = s.budgets.take(3).map((b) {
      final cat = s.categories.where((c) => c.id == b.categoryId);
      return _SharedBudget(
        name: cat.isNotEmpty ? cat.first.name : b.categoryId,
        spent: 0,
        limit: b.limit,
        color: '#00E676',
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Couldn\'t load family members: $_error',
                        style: AppTypography.body(context, size: 12),),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          // Header
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 560;
              final headerLeft = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [
                        AppColors.iris.withValues(alpha: 0.3),
                        AppColors.iris.withValues(alpha: 0.05),
                      ],),
                    ),
                    child: const Icon(Icons.group_outlined,
                        color: AppColors.iris, size: 20,),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.family.familyAccounts,
                            style: AppTypography.heading(context, size: 20),),
                        const SizedBox(height: 2),
                        Text(
                          t.family.sharedFinances,
                          style: AppTypography.body(context, size: 13)
                              .copyWith(color: l.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final inviteBtn = GradientButton(
                icon: const Icon(Icons.person_add_outlined, size: 16),
                onPressed: () => _openInviteDialog(context, t),
                child: Text(t.family.inviteMember),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerLeft,
                    const SizedBox(height: 14),
                    inviteBtn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [headerLeft, inviteBtn],
              );
            },),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),

          const SizedBox(height: 16),

          // Overview
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 640 ? 2 : 1;
              final children = <Widget>[
                _OverviewStat(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.iris,
                  label: t.family.totalFamilyBalance,
                  value: AmountText(
                      value: totalFamilyBalance,
                      currency: currency,
                      size: 22,
                      weight: FontWeight.bold,
                      compact: true,),
                ),
                _OverviewStat(
                  icon: Icons.group_outlined,
                  iconColor: AppColors.cyan,
                  label: t.family.members,
                  value: Text('${members.length}',
                      style: AppTypography.amount(context,
                          size: 22, weight: FontWeight.bold,),),
                  footnote: 'Across 1 household',
                ),
              ];
              if (cols == 2) {
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 16),
                    Expanded(child: children[1]),
                  ],
                );
              }
              return Column(children: [
                children[0],
                const SizedBox(height: 16),
                children[1],
              ],);
            },),
          )
              .animate(delay: 50.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),

          const SizedBox(height: 20),

          // Members
          SectionHeader(
            title: t.family.members,
            subtitle: t.misc.peopleInFamily,
          ).animate(delay: 80.ms).fadeIn(),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1024 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
            final width = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(members.length, (i) {
                final m = members[i];
                return SizedBox(
                  width: width,
                  child: _FamilyMemberCard(
                    member: m,
                    currency: currency,
                    roleLabel: _roleLabel(t, m.role),
                    youLabel: t.family.you,
                  ),
                )
                    .animate(delay: Duration(milliseconds: 100 + i * 50))
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, duration: 400.ms);
              }),
            );
          },),

          const SizedBox(height: 20),

          // Shared budgets + Permissions
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1024;
            final shared = GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: t.family.sharedBudgets,
                    subtitle: t.misc.trackFamilySpending,
                  ),
                  const SizedBox(height: 16),
                  ...sharedBudgets.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _SharedBudgetRow(
                            budget: b, currency: currency,),
                      ),),
                ],
              ),
            );
            final perms = GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: t.family.permissions),
                  const SizedBox(height: 16),
                  _PermissionRow(
                    icon: Icons.workspace_premium,
                    color: AppColors.iris,
                    title: t.family.admin,
                    desc: 'Full access · manage members & budgets',
                  ),
                  const SizedBox(height: 12),
                  _PermissionRow(
                    icon: Icons.group,
                    color: AppColors.cyan,
                    title: t.family.member,
                    desc: 'Add transactions · view shared budgets',
                  ),
                  const SizedBox(height: 12),
                  _PermissionRow(
                    icon: Icons.visibility_outlined,
                    color: l.mutedForeground,
                    title: t.family.viewer,
                    desc: 'Read-only access to shared data',
                  ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: shared),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: perms),
                ],
              );
            }
            return Column(children: [
              shared,
              const SizedBox(height: 16),
              perms,
            ],);
          },)
              .animate(delay: 300.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),
        ],
      ),
    );
  }
}

// ---------- helpers ----------

class _FamilyMember {
  final String id;
  final String name;
  final String role;
  final String color;
  final double spend;
  final double budget;
  final bool isYou;
  const _FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.color,
    required this.spend,
    required this.budget,
    this.isYou = false,
  });
}

class _SharedBudget {
  final String name;
  final double spent;
  final double limit;
  final String color;
  const _SharedBudget({
    required this.name,
    required this.spent,
    required this.limit,
    required this.color,
  });
}

String _roleLabel(AppT t, String role) {
  switch (role) {
    case 'admin':
      return t.family.admin;
    case 'viewer':
      return t.family.viewer;
    default:
      return t.family.member;
  }
}

({IconData icon, Color color}) _roleMeta(String role) {
  switch (role) {
    case 'admin':
      return (icon: Icons.workspace_premium, color: AppColors.iris);
    case 'viewer':
      return (icon: Icons.visibility_outlined, color: Colors.grey);
    default:
      return (icon: Icons.group, color: AppColors.cyan);
  }
}

Color _parseHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h, radix: 16));
  return AppColors.iris;
}

String _initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget value;
  final String? footnote;
  const _OverviewStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              iconColor.withValues(alpha: 0.3),
              iconColor.withValues(alpha: 0.05),
            ],),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: AppTypography.label(context, size: 10).copyWith(
                      letterSpacing: 1.2, color: l.mutedForeground,),),
              const SizedBox(height: 2),
              DefaultTextStyle.merge(
                style: AppTypography.amount(context,
                    size: 22, weight: FontWeight.bold,),
                child: value,
              ),
              if (footnote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    footnote!,
                    style: AppTypography.body(context, size: 11)
                        .copyWith(color: l.mutedForeground),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  final _FamilyMember member;
  final String currency;
  final String roleLabel;
  final String youLabel;
  const _FamilyMemberCard({
    required this.member,
    required this.currency,
    required this.roleLabel,
    required this.youLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final m = member;
    final meta = _roleMeta(m.role);
    final pctUsed = m.budget > 0
        ? (m.spend / m.budget * 100).round().clamp(0, 100)
        : 0;
    final barColor = pctUsed >= 90
        ? AppColors.error
        : pctUsed >= 75
            ? AppColors.warning
            : AppColors.success;
    final avatarColor = _parseHex(m.color);

    return GlassCard(
      hover: true,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          if (m.isYou)
            Positioned(
              right: 0,
              top: 0,
              child: GradientPill(child: Text(youLabel)),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          avatarColor,
                          Color.lerp(avatarColor, AppColors.cyan, 0.5)!,
                        ],
                      ),
                    ),
                    child: Text(
                      _initials(m.name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style: AppTypography.body(context,
                                size: 15, weight: FontWeight.w600,),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3,),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(meta.icon, size: 12, color: meta.color),
                              const SizedBox(width: 4),
                              Text(roleLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: meta.color,),),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly spend',
                      style: AppTypography.label(context, size: 11)
                          .copyWith(color: l.mutedForeground),),
                  Text(
                    '${formatMoney(m.spend, currency, compact: true)} / ${formatMoney(m.budget, currency, compact: true)}',
                    style: AppTypography.label(context,
                        size: 12, weight: FontWeight.w500,),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pctUsed / 100,
                  minHeight: 8,
                  backgroundColor: l.surface3,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$pctUsed% of personal budget',
                style: AppTypography.label(context, size: 11)
                    .copyWith(color: l.mutedForeground),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharedBudgetRow extends StatelessWidget {
  final _SharedBudget budget;
  final String currency;
  const _SharedBudgetRow({required this.budget, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final b = budget;
    final pct =
        b.limit > 0 ? (b.spent / b.limit * 100).round().clamp(0, 100) : 0;
    final color = _parseHex(b.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(b.name,
                    style: AppTypography.body(context,
                        size: 13, weight: FontWeight.w500,),),
              ],
            ),
            Text(
              '${formatMoney(b.spent, currency, compact: true)} / ${formatMoney(b.limit, currency, compact: true)}',
              style: AppTypography.label(context, size: 12)
                  .copyWith(color: l.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: l.surface3,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _PermissionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body(context,
                        size: 13, weight: FontWeight.w500,),),
                const SizedBox(height: 2),
                Text(desc,
                    style: AppTypography.body(context, size: 11)
                        .copyWith(color: l.mutedForeground),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Invite dialog ----------

class _InviteDialog extends ConsumerStatefulWidget {
  final AppT t;
  final VoidCallback onInvited;
  const _InviteDialog({required this.t, required this.onInvited});

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  String _email = '';
  String _role = 'member';
  bool _sending = false;

  Future<void> _submit() async {
    final t = widget.t;
    if (_email.trim().isEmpty) {
      showAppToast(context, t.messages.enterEmail, kind: ToastKind.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await FinTrackRepository.inviteFamilyMember(email: _email.trim(), role: _role);
      if (!mounted) return;
      showAppToast(context, t.family.inviteSent, description: _email);
      widget.onInvited();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      // Real server reason, e.g. "User not found with this email" or
      // "Member already added" — not a generic fake-success toast.
      showAppToast(context, e.toString().replaceFirst('Exception: ', ''), kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final l = context.lumina;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.family.inviteMember,
                    style: AppTypography.heading(context, size: 18),),
                const SizedBox(height: 4),
                Text(
                  t.family.sharedFinances,
                  style: AppTypography.body(context, size: 12)
                      .copyWith(color: l.mutedForeground),
                ),
                const SizedBox(height: 18),
                Text(t.family.email,
                    style: AppTypography.label(context, size: 12),),
                const SizedBox(height: 6),
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(hintText: 'priya@example.com'),
                  onChanged: (v) => _email = v,
                ),
                const SizedBox(height: 14),
                Text(t.family.role,
                    style: AppTypography.label(context, size: 12),),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('${t.family.admin} · full access',
                          style: AppTypography.body(context, size: 13),),
                    ),
                    DropdownMenuItem(
                      value: 'member',
                      child: Text('${t.family.member} · add & view',
                          style: AppTypography.body(context, size: 13),),
                    ),
                    DropdownMenuItem(
                      value: 'viewer',
                      child: Text('${t.family.viewer} · read-only',
                          style: AppTypography.body(context, size: 13),),
                    ),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'member'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.common.cancel),
                    ),
                    const SizedBox(width: 8),
                    GradientButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t.family.inviteSent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
