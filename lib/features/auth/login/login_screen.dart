import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/toast.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/fintrack_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import 'whatsapp_login_sheet.dart';

/// Login screen — professional UI with social login buttons + email/password form.
/// Email domains are NOT restricted; any valid email is accepted.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final emailRe = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!emailRe.hasMatch(s)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    return null;
  }

  void _showNotConfigured(BuildContext context, String provider) {
    showAppToast(
      context,
      '$provider sign-in needs OAuth credentials configured before it can go live.',
      description: 'Use email or WhatsApp to sign in for now.',
      kind: ToastKind.info,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(authProvider.notifier).setError(null);

    try {
      final result = await AuthRepository.login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      ref.read(authProvider.notifier).setAuthResult(result);
      // Pull fresh server data so dashboard/features show real values.
      await ref.read(fintrackProvider.notifier).syncFromServer();
      if (!mounted) return;
      // Verified accounts go straight in; unverified must confirm via OTP.
      if (result.user.emailVerified) {
        context.go('/dashboard');
      } else {
        context.go('/otp?email=$email&purpose=login');
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(authProvider.notifier).setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final state = ref.watch(authProvider);
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to FinTrack Pro',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Social login buttons ──────────────────────────────────────
            _SocialButton(
              icon: 'google',
              label: 'Continue with Google',
              color: l.surface3,
              textColor: l.foreground,
              onTap: () => _showNotConfigured(context, 'Google'),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 12),
            _SocialButton(
              icon: 'facebook',
              label: 'Continue with Facebook',
              color: const Color(0xFF1877F2),
              textColor: Colors.white,
              onTap: () => _showNotConfigured(context, 'Facebook'),
            ).animate().fadeIn(duration: 300.ms, delay: 60.ms),
            const SizedBox(height: 12),
            _SocialButton(
              icon: 'whatsapp',
              label: 'Continue with WhatsApp',
              color: const Color(0xFF25D366),
              textColor: Colors.white,
              onTap: () => showWhatsAppLoginSheet(context, ref),
            ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
            const SizedBox(height: 24),

            // ── Divider ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: Divider(color: l.border, thickness: 0.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or continue with email',
                    style: AppTypography.body(context, size: 12)
                        .copyWith(color: l.mutedForeground),
                  ),
                ),
                Expanded(child: Divider(color: l.border, thickness: 0.5)),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 180.ms),
            const SizedBox(height: 20),

            // ── Error banner ─────────────────────────────────────────────
            if (state.error != null)
              AuthErrorBanner(message: state.error!)
                  .animate()
                  .fadeIn(duration: 250.ms),

            // ── Email field ──────────────────────────────────────────────
            AuthTextField(
              controller: _emailController,
              label: 'Email address',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              prefixIcon: Icon(Icons.email_outlined, color: l.mutedForeground, size: 20),
            ).animate().fadeIn(duration: 300.ms, delay: 240.ms).slideY(begin: 0.05),
            const SizedBox(height: 16),

            // ── Password field ───────────────────────────────────────────
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              validator: _validatePassword,
              prefixIcon: Icon(Icons.lock_outline, color: l.mutedForeground, size: 20),
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
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05),

            // ── Forgot password ──────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.body(context, size: 13)
                      .copyWith(color: AppColors.iris),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Submit button ────────────────────────────────────────────
            GradientButton(
              expanded: true,
              loading: state.loading,
              onPressed: state.loading ? null : _submit,
              child: const Text('Log in'),
            ).animate().fadeIn(duration: 300.ms, delay: 360.ms),
            const SizedBox(height: 20),

            // ── Sign-up link ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                  style: AppTypography.body(context, size: 13)
                      .copyWith(color: l.mutedForeground),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    'Sign up',
                    style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                        .copyWith(color: AppColors.iris),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 420.ms),
          ],
        ),
      ),
    );
  }
}

/// A professional-looking social login button with an icon and label.
class _SocialButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: (color == const Color(0xFF1877F2) || color == const Color(0xFF25D366))
                ? Colors.transparent
                : context.lumina.border,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIcon(
              assetName: icon,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.body(context, size: 15, weight: FontWeight.w600)
                  .copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a clean icon mark for each social login provider. These are
/// deliberately simple, generic renditions (a lettermark, a Material glyph,
/// a chat icon) rather than pixel-accurate reproductions of each company's
/// registered logo artwork.
class _SocialIcon extends StatelessWidget {
  final String assetName;
  final double size;
  final Color? color;

  const _SocialIcon({required this.assetName, required this.size}) : color = null;

  @override
  Widget build(BuildContext context) {
    if (assetName.contains('google')) {
      return Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4285F4),
            height: 1,
          ),
        ),
      );
    }
    if (assetName.contains('whatsapp')) {
      return Icon(Icons.chat_bubble_rounded, size: size * 0.9, color: Colors.white);
    }
    if (assetName.contains('facebook')) {
      return Icon(Icons.facebook, size: size, color: Colors.white);
    }
    return Icon(Icons.account_circle, size: size, color: color);
  }
}