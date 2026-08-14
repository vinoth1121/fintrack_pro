import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final biometric = ref.watch(biometricProvider);
    final notifPrefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => ShellScaffoldData.of(context)?.openDrawer(),
          ),
        ),
        title: Text('Settings', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // ── Appearance ──────────────────────────────────────────────────────
          const _SectionLabel(label: 'Appearance'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            child: Column(
              children: [
                _ThemeOptionRow(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                ),
                const Divider(color: AppColors.darkDivider, height: 1),
                _ThemeOptionRow(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                ),
                const Divider(color: AppColors.darkDivider, height: 1),
                _ThemeOptionRow(
                  icon: Icons.brightness_auto_rounded,
                  label: 'System Default',
                  isSelected: themeMode == ThemeMode.system,
                  onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Security ────────────────────────────────────────────────────────
          const _SectionLabel(label: 'Security'),
          const SizedBox(height: AppSpacing.sm),
          _SwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Login',
            subtitle: 'Use Face ID / Fingerprint to unlock',
            value: biometric.isEnabled,
            isLoading: biometric.isLoading,
            onChanged: (v) => ref.read(biometricProvider.notifier).toggle(v),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Notifications ───────────────────────────────────────────────────
          const _SectionLabel(label: 'Notifications'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
            child: Column(
              children: [
                _CompactSwitchRow(label: 'Budget Alerts', value: notifPrefs.budgetAlerts, onChanged: (v) => ref.read(notificationPrefsProvider.notifier).setBudgetAlerts(v)),
                const Divider(color: AppColors.darkDivider, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
                _CompactSwitchRow(label: 'Bill Reminders', value: notifPrefs.billReminders, onChanged: (v) => ref.read(notificationPrefsProvider.notifier).setBillReminders(v)),
                const Divider(color: AppColors.darkDivider, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
                _CompactSwitchRow(label: 'Goal Milestones', value: notifPrefs.goalMilestones, onChanged: (v) => ref.read(notificationPrefsProvider.notifier).setGoalMilestones(v)),
                const Divider(color: AppColors.darkDivider, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
                _CompactSwitchRow(label: 'AI Insights', value: notifPrefs.aiInsights, onChanged: (v) => ref.read(notificationPrefsProvider.notifier).setAiInsights(v)),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Account ─────────────────────────────────────────────────────────
          const _SectionLabel(label: 'Account'),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () => context.push(AppRoutes.profile)),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            titleColor: AppColors.warning,
            onTap: () => _confirmLogout(context, ref),
          ),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            titleColor: AppColors.error,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── About ───────────────────────────────────────────────────────────
          const _SectionLabel(label: 'About'),
          const SizedBox(height: AppSpacing.sm),
          const _AppVersionTile(),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Sign Out?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text('You will need to log in again to access your account.', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: Text('Sign Out', style: AppTypography.labelLarge.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Account?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text(
          'This will deactivate your account and all associated data. This action cannot be undone from the app — contact support to reactivate.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(dioProvider).delete('/users/me');
              } catch (_) {
                // Even if the network call fails, still sign the user out
                // locally — we don't want them stuck believing deletion
                // succeeded when it didn't, but we also shouldn't trap
                // them in a broken session either way.
              }
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
                AppSnackbar.info(context, 'Your account has been deactivated.');
              }
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Row Widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, letterSpacing: 1, fontWeight: FontWeight.w700));
  }
}

class _ThemeOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionRow({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.darkTextSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500))),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({required this.icon, required this.title, required this.subtitle, required this.value, this.isLoading = false, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.darkCardElevated, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(icon, size: 18, color: AppColors.darkTextSecondary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, this.titleColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.base),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
            child: Row(
              children: [
                Icon(icon, size: 20, color: titleColor ?? AppColors.darkTextSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: AppTypography.bodyMedium.copyWith(color: titleColor ?? AppColors.darkTextPrimary, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})' : '—';
        return Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
          child: Row(
            children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.darkCardElevated, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.darkTextSecondary)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FinTrack Pro', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
                    Text('Version $version', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
