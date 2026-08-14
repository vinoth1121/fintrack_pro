import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/toast.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/repositories/auth_repository.dart';

/// Reset-password screen — accepts the 6-digit code (emailed to [email]) plus
/// a new password + confirmation, then routes back to /login on success.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCode(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Enter the 6-digit code';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Confirm your password';
    if (s != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthRepository.resetPassword(
        email: widget.email,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      showAppToast(context, 'Password reset successfully', kind: ToastKind.success);
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return AuthScaffold(
      title: 'Reset password',
      subtitle:
          'Enter the code sent to ${widget.email} and your new password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              AuthErrorBanner(message: _error!).animate().fadeIn(duration: 250.ms),
            AuthTextField(
              controller: _codeController,
              label: '6-digit code',
              keyboardType: TextInputType.number,
              validator: _validateCode,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'New password',
              obscureText: _obscurePassword,
              validator: _validatePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: l.mutedForeground,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 60.ms).slideY(begin: 0.05),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmController,
              label: 'Confirm password',
              obscureText: _obscureConfirm,
              validator: _validateConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: l.mutedForeground,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 120.ms).slideY(begin: 0.05),
            const SizedBox(height: 24),
            GradientButton(
              expanded: true,
              loading: _loading,
              onPressed: _loading ? null : _submit,
              child: const Text('Reset password'),
            ).animate().fadeIn(duration: 300.ms, delay: 180.ms),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Remembered it?',
                  style: AppTypography.body(context, size: 13)
                      .copyWith(color: l.mutedForeground),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Back to login',
                    style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                        .copyWith(color: AppColors.iris),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 240.ms),
          ],
        ),
      ),
    );
  }
}
