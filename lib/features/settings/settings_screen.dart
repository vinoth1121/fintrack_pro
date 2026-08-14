import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/config/server_config.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

const _currencies = <String>['INR', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'AUD', 'CAD'];

/// Settings screen — faithful Flutter port of settings.tsx.
///
/// The SettingsScreen itself is a thin ConsumerWidget that delegates to
/// a private ConsumerStatefulWidget which manages the local UI state
/// (notification toggles, biometric switch, default view, etc.) while
/// pulling translations + theme + profile from Riverpod.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _SettingsBody();
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody();

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  final _notifPrefs = <String, bool>{
    'budget': true,
    'bills': true,
    'ai': true,
    'weekly': false,
  };
  bool _biometric = false;
  String _defaultTxView = 'expenses';

  final _serverUrlController = TextEditingController();
  bool _testingConnection = false;
  ServerTestResult? _lastTestResult;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = dioClient.options.baseUrl;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _testServerConnection() async {
    setState(() { _testingConnection = true; _lastTestResult = null; });
    final result = await ServerConfig.testConnection(_serverUrlController.text);
    if (!mounted) return;
    setState(() { _testingConnection = false; _lastTestResult = result; });
  }

  Future<void> _saveServerUrl() async {
    await ServerConfig.setOverride(_serverUrlController.text);
    if (!mounted) return;
    showAppToast(context, 'Server URL saved — the app will use it immediately.');
    _testServerConnection();
  }

  void _notifToggle(String key, bool v) {
    final t = ref.read(tProvider);
    setState(() => _notifPrefs[key] = v);
    final msg = t.messages.alertsOnOff
        .replaceAll('{key}', key)
        .replaceAll('{state}', v ? t.messages.onState : t.messages.offState);
    showAppToast(context, msg);
  }

  void _setBiometric(bool v) {
    final t = ref.read(tProvider);
    setState(() => _biometric = v);
    final msg = t.messages.biometricStatus
        .replaceAll('{name}', t.settings.biometric)
        .replaceAll('{state}', v ? t.messages.onState : t.messages.offState);
    showAppToast(context, msg);
  }

  Future<void> _confirmReset(BuildContext context, AppT t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${t.settings.resetDemo}?',
            style: AppTypography.heading(context, size: 18),),
        content: Text(
          'This will erase all your transactions, budgets, goals, and notes, restoring the original sample data. This action cannot be undone.',
          style: AppTypography.body(context, size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(t.settings.resetDemo),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(fintrackProvider.notifier).resetAll();
    showAppToast(this.context, t.settings.resetDemo);
  }

  Future<void> _confirmDelete(BuildContext context, AppT t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${t.settings.deleteAccount}?',
            style: AppTypography.heading(context, size: 18),),
        content: Text(
          'This is a permanent action. All your financial history, goals, and settings will be lost forever.',
          style: AppTypography.body(context, size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    showAppToast(this.context, t.settings.deleteAccount,
        description: 'This is a demo — your data is safe.',
        kind: ToastKind.error,);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final s = ref.watch(fintrackProvider);
    final l = context.lumina;
    final theme = s.theme;
    final profile = s.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Appearance
          _SettingsCard(
            title: t.settings.appearance,
            subtitle: t.settingsDesc.appearanceSub,
            icon: Icons.palette_outlined,
            delay: 0,
            children: [
              _SettingRow(
                icon: theme == 'dark'
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                label: t.settings.theme,
                description: t.settingsDesc.switchTheme,
                control: _ThemeToggle(
                  isDark: theme == 'dark',
                  onChanged: (dark) => ref
                      .read(fintrackProvider.notifier)
                      .setTheme(dark ? 'dark' : 'light'),
                  darkLabel: t.settings.dark,
                  lightLabel: t.settings.light,
                ),
              ),
            ],
          ),

          // Server connection — required before publishing: the default
          // apiBaseUrl only works on an emulator/localhost, never for a real
          // installed app. This card lets it be changed at runtime.
          _SettingsCard(
            title: 'Server connection',
            subtitle: 'Point the app at your deployed backend',
            icon: Icons.dns_outlined,
            delay: 60,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _serverUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'https://your-backend.example.com',
                        labelText: 'API base URL',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testingConnection ? null : _testServerConnection,
                            child: _testingConnection
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Test connection'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GradientButton(
                            onPressed: _saveServerUrl,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    if (_lastTestResult != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _lastTestResult!.ok ? Icons.check_circle : Icons.error_outline,
                            size: 16,
                            color: _lastTestResult!.ok ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _lastTestResult!.message,
                              style: AppTypography.body(context, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Preferences
          _SettingsCard(
            title: t.settings.preferences,
            subtitle: t.settingsDesc.preferencesSub,
            icon: Icons.view_module_outlined,
            delay: 50,
            children: [
              _SettingRow(
                icon: Icons.language,
                label: t.settings.language,
                description: t.settingsDesc.appLanguage,
                control: _LanguageDropdown(
                  current: s.locale,
                  onChanged: (code) {
                    ref.read(fintrackProvider.notifier).setLocale(code);
                    showAppToast(context, t.settings.languageUpdated);
                  },
                ),
              ),
              _SettingRow(
                icon: Icons.monetization_on_outlined,
                label: t.profile.baseCurrency,
                description: t.settingsDesc.usedForAmounts,
                control: _CurrencyDropdown(
                  current: profile.baseCurrency,
                  onChanged: (v) {
                    ref.read(fintrackProvider.notifier).updateProfile(
                          profile.copyWith(baseCurrency: v),
                        );
                    showAppToast(context,
                        '${t.profile.baseCurrency}: $v',);
                  },
                ),
              ),
              _SettingRow(
                icon: Icons.view_module_outlined,
                label: t.settings.defaultView,
                description: t.settingsDesc.defaultViewDesc,
                control: _DefaultViewDropdown(
                  current: _defaultTxView,
                  onChanged: (v) => setState(() => _defaultTxView = v),
                  expensesLabel: t.nav.expenses,
                  incomeLabel: t.nav.income,
                  dashboardLabel: t.nav.dashboard,
                ),
              ),
            ],
          ),

          // Notifications
          _SettingsCard(
            title: t.settings.notificationsSection,
            subtitle: t.settingsDesc.notifSub,
            icon: Icons.notifications_outlined,
            delay: 100,
            children: [
              _SettingRow(
                icon: Icons.notifications_active_outlined,
                label: t.settings.budgetAlerts,
                description: t.settingsDesc.budgetAlertsDesc,
                control: Switch(
                  value: _notifPrefs['budget']!,
                  onChanged: (v) => _notifToggle('budget', v),
                ),
              ),
              _SettingRow(
                icon: Icons.refresh,
                label: t.settings.billReminders,
                description: t.settingsDesc.billRemindersDesc,
                control: Switch(
                  value: _notifPrefs['bills']!,
                  onChanged: (v) => _notifToggle('bills', v),
                ),
              ),
              _SettingRow(
                icon: Icons.info_outline,
                label: t.settings.aiInsights,
                description: t.settingsDesc.aiInsightsDesc,
                control: Switch(
                  value: _notifPrefs['ai']!,
                  onChanged: (v) => _notifToggle('ai', v),
                ),
              ),
              _SettingRow(
                icon: Icons.description_outlined,
                label: t.settings.weeklySummary,
                description: t.settingsDesc.weeklySummaryDesc,
                control: Switch(
                  value: _notifPrefs['weekly']!,
                  onChanged: (v) => _notifToggle('weekly', v),
                ),
              ),
            ],
          ),

          // Security
          _SettingsCard(
            title: t.settings.security,
            subtitle: t.settingsDesc.securitySub,
            icon: Icons.shield_outlined,
            delay: 150,
            children: [
              _SettingRow(
                icon: Icons.fingerprint,
                label: t.settings.biometric,
                description: t.settingsDesc.biometricDesc,
                control: Switch(
                  value: _biometric,
                  onChanged: _setBiometric,
                ),
              ),
              _SettingRow(
                icon: Icons.key,
                label: t.settings.changePin,
                description: t.settingsDesc.pinDesc,
                control: GhostButton(
                  onPressed: () => showAppToast(
                      context, '${t.settings.changePin} …',
                      kind: ToastKind.info,),
                  child: Text(t.common.edit),
                ),
              ),
              _SettingRow(
                icon: Icons.lock_outline,
                label: t.settings.changePassword,
                description: t.settingsDesc.passwordDesc,
                control: GhostButton(
                  onPressed: () => showAppToast(
                      context, '${t.settings.changePassword} …',
                      kind: ToastKind.info,),
                  child: Text(t.common.edit),
                ),
              ),
            ],
          ),

          // Data
          _SettingsCard(
            title: t.settings.data,
            subtitle: t.messages.manageYourData,
            icon: Icons.storage_outlined,
            delay: 200,
            children: [
              _SettingRow(
                icon: Icons.download_outlined,
                label: t.settings.exportData,
                description: t.messages.downloadJson,
                control: GhostButton(
                  onPressed: () =>
                      showAppToast(context, t.messages.dataExported),
                  child: Text(t.settings.exportData),
                ),
              ),
              _SettingRow(
                icon: Icons.upload_outlined,
                label: t.messages.importBackup,
                description: t.messages.restoreFromJson,
                control: GhostButton(
                  onPressed: () => showAppToast(context,
                      t.messages.fileReadError,
                      kind: ToastKind.error,),
                  child: Text(t.messages.import_),
                ),
              ),
              _SettingRow(
                icon: Icons.refresh,
                label: t.settings.resetDemo,
                description: t.messages.restoreOriginal,
                control: GhostButton(
                  onPressed: () => _confirmReset(context, t),
                  child: Text(t.settings.resetDemo),
                ),
              ),
              _SettingRow(
                icon: Icons.delete_outline,
                label: t.settings.deleteAccount,
                description: t.messages.permanentlyRemove,
                control: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6,),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _confirmDelete(context, t),
                    child: Text(t.common.delete,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,),),
                  ),
                ),
              ),
            ],
          ),

          // About
          _SettingsCard(
            title: t.settings.about,
            subtitle: t.settingsDesc.aboutSub,
            icon: Icons.info_outline,
            delay: 250,
            children: [
              _SettingRow(
                icon: Icons.info_outline,
                label: t.settings.version,
                description: 'FinTrack Pro · ${t.settings.luminaDesign}',
                control: Text('1.0.0',
                    style: AppTypography.amount(context,
                            size: 12, weight: FontWeight.w500,)
                        .copyWith(color: l.mutedForeground),),
              ),
              _SettingRow(
                icon: Icons.description_outlined,
                label: t.settings.privacyPolicy,
                description: t.settingsDesc.privacyDesc,
                control: const Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey,),
              ),
              _SettingRow(
                icon: Icons.description_outlined,
                label: t.settings.terms,
                description: t.settingsDesc.termsDesc,
                control: const Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey,),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.iris,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showAppToast(
                          context, '${t.settings.privacyPolicy} …',
                          kind: ToastKind.info,),
                      child: Text(t.settings.privacyPolicy,
                          style: const TextStyle(fontSize: 12),),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.iris,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showAppToast(
                          context, '${t.settings.terms} …',
                          kind: ToastKind.info,),
                      child: Text(t.settings.terms,
                          style: const TextStyle(fontSize: 12),),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.iris,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showAppToast(
                          context, t.messages.openingLicenses,
                          kind: ToastKind.info,),
                      child: const Text('Licenses',
                          style: TextStyle(fontSize: 12),),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Footer signature
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'FinTrack Pro · ${t.settings.luminaDesign}',
              textAlign: TextAlign.center,
              style: AppTypography.body(context, size: 11)
                  .copyWith(color: l.mutedForeground),
            ),
          ).animate(delay: 350.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ---------- helpers ----------

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final int delay;
  final List<Widget> children;
  const _SettingsCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.delay,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: [
                        AppColors.iris.withValues(alpha: 0.3),
                        AppColors.iris.withValues(alpha: 0.05),
                      ],),
                    ),
                    child: Icon(icon, color: AppColors.iris, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTypography.heading(context, size: 15),),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle!,
                                style: AppTypography.body(context, size: 11)
                                    .copyWith(color: l.mutedForeground),),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: l.border),
            ...children,
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.04, end: 0, duration: 400.ms);
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final Widget control;
  const _SettingRow({
    required this.icon,
    required this.label,
    this.description,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: l.surface3.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: l.mutedForeground, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body(context,
                        size: 13, weight: FontWeight.w500,),),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(description!,
                        style: AppTypography.body(context, size: 11)
                            .copyWith(color: l.mutedForeground),),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final String darkLabel;
  final String lightLabel;
  const _ThemeToggle({
    required this.isDark,
    required this.onChanged,
    required this.darkLabel,
    required this.lightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            active: isDark,
            onTap: () => onChanged(true),
            icon: Icons.dark_mode_outlined,
            label: darkLabel,
          ),
          _segment(
            active: !isDark,
            onTap: () => onChanged(false),
            icon: Icons.light_mode_outlined,
            label: lightLabel,
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required bool active,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: active ? AppColors.brandGradient : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? Colors.white : Colors.grey,),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _LanguageDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          style: AppTypography.body(context, size: 12),
          items: locales
              .map((loc) => DropdownMenuItem(
                    value: loc.code,
                    child: Text(
                      '${loc.flag} ${loc.nativeName}',
                      style: AppTypography.body(context, size: 12),
                    ),
                  ),)
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _CurrencyDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          style: AppTypography.body(context, size: 12),
          items: _currencies
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('$c · ${currencySymbol(c)}',
                        style: AppTypography.body(context, size: 12),),
                  ),)
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _DefaultViewDropdown extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final String expensesLabel;
  final String incomeLabel;
  final String dashboardLabel;
  const _DefaultViewDropdown({
    required this.current,
    required this.onChanged,
    required this.expensesLabel,
    required this.incomeLabel,
    required this.dashboardLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: l.border),
        color: l.surface3.withValues(alpha: 0.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          style: AppTypography.body(context, size: 12),
          items: [
            DropdownMenuItem(
                value: 'expenses',
                child: Text(expensesLabel,
                    style: AppTypography.body(context, size: 12),),),
            DropdownMenuItem(
                value: 'income',
                child: Text(incomeLabel,
                    style: AppTypography.body(context, size: 12),),),
            DropdownMenuItem(
                value: 'dashboard',
                child: Text(dashboardLabel,
                    style: AppTypography.body(context, size: 12),),),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
