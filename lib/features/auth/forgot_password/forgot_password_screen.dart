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

/// Forgot-password screen — accepts an email and triggers a reset-code email.
/// Always shows the same neutral success message and routes to /reset-password
/// regardless of whether the email exists (to avoid leaking account existence).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(s)) {
      return 'Enter a valid email';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _loading = true);
    try {
      await AuthRepository.forgotPassword(email: email);
      if (!mounted) return;
      _proceed(email);
    } catch (_) {
      // Don't leak whether the email exists — show the same neutral toast
      // and route onward so the experience is identical for any address.
      if (!mounted) return;
      _proceed(email);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _proceed(String email) {
    showAppToast(
      context,
      'If the email exists, a reset code has been sent.',
      kind: ToastKind.success,
    );
    context.go('/reset-password?email=$email');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return AuthScaffold(
      title: 'Forgot password',
      subtitle: 'Enter your email to receive a reset code',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: 24),
            GradientButton(
              expanded: true,
              loading: _loading,
              onPressed: _loading ? null : _submit,
              child: const Text('Send reset code'),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
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
            ).animate().fadeIn(duration: 300.ms, delay: 160.ms),
          ],
        ),
      ),
    );
  }
}
