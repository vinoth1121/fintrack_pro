import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

const _currencies = <String>['INR', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'AUD', 'CAD'];

const _avatarColors = <String>[
  '#6C5CE7',
  '#00D2FF',
  '#00E676',
  '#FFB74D',
  '#FF5252',
  '#448AFF',
  '#FF6FB5',
  '#B388FF',
];

/// Profile screen — faithful Flutter port of profile.tsx.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _openEditDialog(BuildContext context, AppT t, UserProfile profile) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditProfileDialog(t: t, profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final d = ref.watch(derivedProvider);
    final l = context.lumina;
    final profile = s.profile;
    final accounts = s.accounts;

    final savingsPct = (d.savingsRate * 100).round().clamp(0, 100);
    final incomeGoalPct = profile.monthlyIncomeGoal > 0
        ? ((d.monthIncome / profile.monthlyIncomeGoal) * 100)
            .round()
            .clamp(0, 100)
        : 0;

    final avatarColor = _parseHex(profile.avatarColor);
    final savingsMsg = d.savingsRate >= 0.2
        ? 'On track 🎯'
        : d.savingsRate >= 0
            ? 'Could be better'
            : 'Overspending';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 640;
              final left = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          avatarColor,
                          Color.lerp(avatarColor, AppColors.cyan, 0.5)!,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),),
                      ],
                    ),
                    child: Text(
                      _initials(profile.name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GradientPill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12),
                              SizedBox(width: 4),
                              Text('Premium member'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(profile.name,
                            style: AppTypography.display(context, size: 22),),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mail_outline,
                                    size: 14, color: AppColors.iris,),
                                const SizedBox(width: 4),
                                Text(profile.email,
                                    style: AppTypography.body(context,
                                        size: 13,)
                                        .copyWith(color: l.mutedForeground),),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: AppColors.iris,),
                                const SizedBox(width: 4),
                                Text(
                                  '${t.profile.memberSince} Jan 2024',
                                  style: AppTypography.body(context, size: 13)
                                      .copyWith(color: l.mutedForeground),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final editBtn = GhostButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _openEditDialog(context, t, profile),
                child: Text(t.profile.editProfile),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    left,
                    const SizedBox(height: 16),
                    editBtn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [left, editBtn],
              );
            },),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),

          const SizedBox(height: 16),

          // Stats row
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 3 : 1;
            final width = (c.maxWidth - 12 * (cols - 1)) / cols;
            final tiles = <Widget>[
              StatTile(
                label: t.profile.netWorth,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                accent: 'iris',
                value: AmountText(
                    value: d.netBalance,
                    currency: profile.baseCurrency,
                    size: 22,
                    weight: FontWeight.bold,
                    compact: true,),
              ),
              StatTile(
                label: t.profile.monthlyIncomeGoal,
                icon: const Icon(Icons.flag_outlined, size: 16),
                accent: 'cyan',
                value: AmountText(
                    value: profile.monthlyIncomeGoal,
                    currency: profile.baseCurrency,
                    size: 22,
                    weight: FontWeight.bold,
                    compact: true,),
              ),
              StatTile(
                label: t.profile.baseCurrency,
                icon: const Icon(Icons.monetization_on_outlined, size: 16),
                accent: 'green',
                value: Text(
                  '${profile.baseCurrency} · ${currencySymbol(profile.baseCurrency)}',
                  style: AppTypography.amount(context,
                      size: 22, weight: FontWeight.bold,),
                ),
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(tiles.length, (i) {
                return SizedBox(width: width, child: tiles[i])
                    .animate(delay: Duration(milliseconds: 50 + i * 50))
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, duration: 400.ms);
              }),
            );
          },),

          const SizedBox(height: 16),

          // Linked accounts
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: t.profile.linkedAccounts,
                  subtitle: '${accounts.length} accounts connected',
                ),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No accounts linked yet.',
                          style: AppTypography.body(context, size: 13)
                              .copyWith(color: l.mutedForeground),),
                    ),
                  )
                else
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 1024
                        ? 3
                        : (c.maxWidth >= 640 ? 2 : 1);
                    final width = (c.maxWidth - 12 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: accounts
                          .map((a) => SizedBox(
                                width: width,
                                child: _AccountCard(
                                  account: a,
                                  currency: profile.baseCurrency,
                                ),
                              ),)
                          .toList(),
                    );
                  },),
              ],
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),

          const SizedBox(height: 16),

          // Financial snapshot
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: t.profile.financialSnapshot,
                  subtitle: t.common.thisMonth,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 640 ? 3 : 1;
                  final width = (c.maxWidth - 12 * (cols - 1)) / cols;
                  final cards = <Widget>[
                    // Savings rate
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: l.border),
                        color: l.surface3.withValues(alpha: 0.3),
                      ),
                      child: Row(
                        children: [
                          ProgressRing(
                            value: savingsPct.toDouble(),
                            size: 72,
                            stroke: 7,
                            color: AppColors.iris,
                            child: Text('$savingsPct%',
                                style: AppTypography.amount(context,
                                    size: 13, weight: FontWeight.bold,),),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.profile.savingsRate.toUpperCase(),
                                    style: AppTypography.label(context,
                                            size: 10,)
                                        .copyWith(
                                            letterSpacing: 1.2,
                                            color: l.mutedForeground,),),
                                const SizedBox(height: 4),
                                Text(savingsMsg,
                                    style: AppTypography.body(context,
                                        size: 13, weight: FontWeight.w500,),),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Net worth
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: l.border),
                        color: l.surface3.withValues(alpha: 0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.profile.netWorth.toUpperCase(),
                              style: AppTypography.label(context, size: 10)
                                  .copyWith(
                                      letterSpacing: 1.2,
                                      color: l.mutedForeground,),),
                          const SizedBox(height: 4),
                          AmountText(
                              value: d.netBalance,
                              currency: profile.baseCurrency,
                              size: 22,
                              weight: FontWeight.w600,
                              compact: true,),
                          const SizedBox(height: 4),
                          Text('Across ${accounts.length} accounts',
                              style: AppTypography.body(context, size: 11)
                                  .copyWith(color: l.mutedForeground),),
                        ],
                      ),
                    ),
                    // Income vs goal
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: l.border),
                        color: l.surface3.withValues(alpha: 0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.profile.incomeVsGoal.toUpperCase(),
                              style: AppTypography.label(context, size: 10)
                                  .copyWith(
                                      letterSpacing: 1.2,
                                      color: l.mutedForeground,),),
                          const SizedBox(height: 4),
                          AmountText(
                              value: d.monthIncome,
                              currency: profile.baseCurrency,
                              size: 22,
                              weight: FontWeight.w600,
                              compact: true,
                              color: AppColors.success,),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: incomeGoalPct / 100,
                              minHeight: 6,
                              backgroundColor: l.surface3,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.success,),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$incomeGoalPct% of ${t.profile.monthlyIncomeGoal}',
                            style: AppTypography.body(context, size: 11)
                                .copyWith(color: l.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards,
                  );
                },),
              ],
            ),
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),
        ],
      ),
    );
  }
}

// ---------- helpers ----------

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
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

IconData _accountKindIcon(String kind) {
  switch (kind) {
    case 'bank':
      return Icons.account_balance;
    case 'cash':
      return Icons.account_balance_wallet_outlined;
    case 'wallet':
      return Icons.account_balance_wallet;
    case 'card':
      return Icons.credit_card;
    case 'investment':
      return Icons.savings_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final String currency;
  const _AccountCard({required this.account, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final a = account;
    final color = _parseHex(a.color);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.3),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: color),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_accountKindIcon(a.kind),
                          color: Colors.white, size: 20,),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: l.border),
                      ),
                      child: Text(a.kind,
                          style: AppTypography.label(context, size: 10)
                              .copyWith(color: l.mutedForeground),),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(a.name,
                    style: AppTypography.body(context,
                        size: 14, weight: FontWeight.w600,),),
                if (a.institution != null) ...[
                  const SizedBox(height: 2),
                  Text(a.institution!,
                      style: AppTypography.body(context, size: 11)
                          .copyWith(color: l.mutedForeground),),
                ],
                const SizedBox(height: 8),
                AmountText(
                    value: a.balance,
                    currency: currency,
                    size: 18,
                    weight: FontWeight.w600,),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Edit profile dialog ----------

class _EditProfileDialog extends ConsumerStatefulWidget {
  final AppT t;
  final UserProfile profile;
  const _EditProfileDialog({required this.t, required this.profile});

  @override
  ConsumerState<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _goalCtrl;
  late String _baseCurrency;
  late String _avatarColor;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _goalCtrl = TextEditingController(text: p.monthlyIncomeGoal.toString());
    _baseCurrency = p.baseCurrency;
    _avatarColor = p.avatarColor;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final l = context.lumina;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.profile.editProfile,
                    style: AppTypography.heading(context, size: 18),),
                const SizedBox(height: 4),
                Text(
                  t.messages.updatePersonalDetails,
                  style: AppTypography.body(context, size: 12)
                      .copyWith(color: l.mutedForeground),
                ),
                const SizedBox(height: 18),
                Text(t.profile.name,
                    style: AppTypography.label(context, size: 12),),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl),
                const SizedBox(height: 12),
                Text(t.profile.email,
                    style: AppTypography.label(context, size: 12),),
                const SizedBox(height: 6),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.profile.baseCurrency,
                              style:
                                  AppTypography.label(context, size: 12),),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _baseCurrency,
                            decoration: const InputDecoration(),
                            items: _currencies
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                          '$c · ${currencySymbol(c)}',
                                          style: AppTypography.body(context,
                                              size: 13,),),
                                    ),)
                                .toList(),
                            onChanged: (v) => setState(
                                () => _baseCurrency = v ?? _baseCurrency,),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.profile.monthlyIncomeGoal,
                              style:
                                  AppTypography.label(context, size: 12),),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _goalCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(t.profile.avatarColor,
                    style: AppTypography.label(context, size: 12),),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _avatarColors.map((c) {
                    final selected = _avatarColor == c;
                    return GestureDetector(
                      onTap: () => setState(() => _avatarColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseHex(c),
                          shape: BoxShape.circle,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16,)
                            : null,
                      ),
                    );
                  }).toList(),
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
                      onPressed: () {
                        final p = widget.profile;
                        ref.read(fintrackProvider.notifier).updateProfile(
                              UserProfile(
                                name: _nameCtrl.text.trim().isEmpty
                                    ? p.name
                                    : _nameCtrl.text.trim(),
                                email: _emailCtrl.text.trim().isEmpty
                                    ? p.email
                                    : _emailCtrl.text.trim(),
                                avatarColor: _avatarColor,
                                baseCurrency: _baseCurrency,
                                monthlyIncomeGoal:
                                    double.tryParse(_goalCtrl.text.trim()) ??
                                        0,
                              ),
                            );
                        showAppToast(context, t.messages.profileUpdated);
                        Navigator.of(context).pop();
                      },
                      child: Text(t.common.saveChanges),
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
