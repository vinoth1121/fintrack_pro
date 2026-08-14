import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

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
        title: Text('Profile', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // ── Avatar & Header ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                          style: AppTypography.displaySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Material(
                        color: AppColors.darkCard,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => AppSnackbar.info(context, 'Photo upload requires cloud storage setup — coming in a future update.'),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.darkBackground, width: 2)),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Text(user?.fullName ?? 'User', style: AppTypography.titleLarge.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
                const SizedBox(height: AppSpacing.sm),
                if (user?.isEmailVerified == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Verified', style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ── Account Section ────────────────────────────────────────────────
          const _SectionLabel(label: 'Account'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            subtitle: 'Name, phone, currency',
            onTap: () => _showEditProfileSheet(context, user),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePasswordSheet(context),
          ),

          const SizedBox(height: AppSpacing.xl),

          const _SectionLabel(label: 'Details'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(AppRadius.base), border: Border.all(color: AppColors.darkBorder, width: 0.5)),
            child: Column(
              children: [
                _DetailRow(label: 'Preferred Currency', value: user?.currency ?? 'USD'),
                const Divider(color: AppColors.darkDivider, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
                _DetailRow(label: 'Phone', value: (user?.phone?.isNotEmpty ?? false) ? user!.phone! : 'Not set'),
                const Divider(color: AppColors.darkDivider, height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
                _DetailRow(label: 'Member Since', value: user != null ? DateFormat('MMM yyyy').format(user.createdAt) : '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(
        initialName: user?.fullName ?? '',
        initialPhone: user?.phone ?? '',
        initialCurrency: user?.currency ?? 'USD',
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ChangePasswordSheet(),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, letterSpacing: 1, fontWeight: FontWeight.w700));
  }
}

// ─── Settings Tile (shared visual style with Settings screen) ─────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.darkCardElevated, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(icon, size: 18, color: AppColors.darkTextSecondary),
                ),
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
                const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary)),
          Text(value, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialCurrency;

  const _EditProfileSheet({required this.initialName, required this.initialPhone, required this.initialCurrency});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _currency;

  static const _currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'AUD', 'CAD'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _currency = widget.initialCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      AppSnackbar.warning(context, 'Name cannot be empty.');
      return;
    }
    final success = await ref.read(editProfileProvider.notifier).save(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      currency: _currency,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnackbar.success(context, 'Profile updated.');
    } else {
      final failure = ref.read(editProfileProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(editProfileProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        decoration: const BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Profile', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(controller: _nameController, label: 'Full Name', prefixIcon: Icons.person_outline_rounded, textCapitalization: TextCapitalization.words),
              const SizedBox(height: AppSpacing.base),
              AppTextField(controller: _phoneController, label: 'Phone (optional)', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.base),
              Text('Currency', style: AppTypography.labelMedium.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: _currencies.map((c) {
                  final isSelected = _currency == c;
                  return GestureDetector(
                    onTap: () => setState(() => _currency = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.darkCardElevated,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.darkBorder, width: isSelected ? 1.2 : 0.5),
                      ),
                      child: Text(c, style: AppTypography.labelSmall.copyWith(color: isSelected ? AppColors.primary : AppColors.darkTextSecondary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppPrimaryButton(label: 'Save Changes', isLoading: formState.isLoading, onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Change Password Sheet ────────────────────────────────────────────────────

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref.read(changePasswordProvider.notifier).changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnackbar.success(context, 'Password changed. Please log in again.');
    } else {
      final failure = ref.read(changePasswordProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(changePasswordProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        decoration: const BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet))),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Change Password', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _currentController,
                  label: 'Current Password',
                  obscureText: _obscureCurrent,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  onSuffixIconTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: _newController,
                  label: 'New Password',
                  obscureText: _obscureNew,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  onSuffixIconTap: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: _confirmController,
                  label: 'Confirm New Password',
                  obscureText: _obscureNew,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) {
                    if (v != _newController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppPrimaryButton(label: 'Update Password', isLoading: formState.isLoading, onTap: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
