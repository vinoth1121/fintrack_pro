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
import '../../../providers/auth_provider.dart';
import '../login/whatsapp_login_sheet.dart';

/// Registration screen — professional UI with social login buttons +
/// full name + email + password with strength meter.
/// Any valid email domain is accepted.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  /// 0..4 scale — none, weak, fair, good, strong
  double _strength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Full name is required';
    if (s.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  // ── Accepts ANY valid email address ────────────────────────────────────
  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';

    final emailRe = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!emailRe.hasMatch(s)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // ── Password strength calculator (zxcvbn-lite heuristic) ────────────────
  void _evaluateStrength(String s) {
    double score = 0;
    if (s.length >= 8) score += 1;
    if (s.length >= 12) score += 0.5;
    if (RegExp(r'[a-z]').hasMatch(s) && RegExp(r'[A-Z]').hasMatch(s)) score += 1;
    if (RegExp(r'\d').hasMatch(s)) score += 0.5;
    if (RegExp(r'[!@#\$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]').hasMatch(s)) score += 1;
    setState(() => _strength = score.clamp(0, 4).toDouble());
  }

  String _strengthLabel() {
    if (_strength < 1.5) return 'Weak';
    if (_strength < 2.5) return 'Fair';
    if (_strength < 3.5) return 'Good';
    return 'Strong';
  }

  Color _strengthColor() {
    if (_strength < 1.5) return Colors.redAccent;
    if (_strength < 2.5) return Colors.orangeAccent;
    if (_strength < 3.5) return Colors.amber.shade600;
    return Colors.greenAccent;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  // ── Submit: send OTP (like login flow) then navigate ──────────────────
  void _showNotConfigured(BuildContext context, String provider) {
    showAppToast(
      context,
      '$provider sign-up needs OAuth credentials configured before it can go live.',
      description: 'Use email or WhatsApp to sign up for now.',
      kind: ToastKind.info,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_strength < 2) {
      setState(() => _error = 'Please choose a stronger password');
      return;
    }

    setState(() => _error = null);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // 1) Call the /api/auth/register endpoint to create the user account
      await AuthRepository.register(name: name, email: email, password: password);
      if (!mounted) return;

      // 2) Send an OTP to verify the email
      final otp = await AuthRepository.sendOtp(
        email: email,
        purpose: 'register',
        password: password,
      );
      if (!mounted) return;

      // Reveal the verification code (dev backend sends it back)
      if (otp.isNotEmpty) {
        showAppToast(
          context,
          'Your verification code',
          description: otp,
          kind: ToastKind.ai,
        );
      } else {
        showAppToast(
          context,
          'Account created',
          description: 'Check your email for the verification code.',
          kind: ToastKind.success,
        );
      }
      context.go('/otp?email=$email&purpose=register');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Sign up to get started with FinTrack Pro',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Social sign-up buttons ───────────────────────────────────
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
                    'or sign up with email',
                    style: AppTypography.body(context, size: 12)
                        .copyWith(color: l.mutedForeground),
                  ),
                ),
                Expanded(child: Divider(color: l.border, thickness: 0.5)),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 180.ms),
            const SizedBox(height: 20),

            // ── Error banner ─────────────────────────────────────────────
            if (_error != null)
              AuthErrorBanner(message: _error!)
                  .animate()
                  .fadeIn(duration: 250.ms),

            // ── Full name ────────────────────────────────────────────────
            AuthTextField(
              controller: _nameController,
              label: 'Full name',
              validator: _validateName,
              keyboardType: TextInputType.name,
              prefixIcon: Icon(Icons.person_outline, color: l.mutedForeground, size: 20),
            ).animate().fadeIn(duration: 300.ms, delay: 240.ms).slideY(begin: 0.05),
            const SizedBox(height: 16),

            // ── Email ────────────────────────────────────────────────────
            AuthTextField(
              controller: _emailController,
              label: 'Email address',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              prefixIcon: Icon(Icons.email_outlined, color: l.mutedForeground, size: 20),
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: 16),

            // ── Password ─────────────────────────────────────────────────
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a strong password',
              obscureText: _obscurePassword,
              validator: _validatePassword,
              onChanged: _evaluateStrength,
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
            ).animate().fadeIn(duration: 300.ms, delay: 360.ms).slideY(begin: 0.05),

            // ── Password strength indicator ──────────────────────────────
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: 300.ms,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  key: ValueKey(_strength.round()),
                  children: [
                    // Segmented bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _strength / 4,
                        backgroundColor: l.surface3.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(_strengthColor()),
                        minHeight: 6,
                      ),
                    ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Password strength',
                          style: AppTypography.body(context, size: 12)
                              .copyWith(color: l.mutedForeground),
                        ),
                        Text(
                          _strengthLabel(),
                          style: AppTypography.body(context,
                            size: 12,
                            weight: FontWeight.w600,
                          ).copyWith(color: _strengthColor()),
                        ),
                      ],
                    ),
                    // Required hints
                    const SizedBox(height: 10),
                    _hint('At least 8 characters',
                        _passwordController.text.length >= 8),
                    _hint('Uppercase & lowercase',
                        _hasUpper(_passwordController.text) && _hasLower(_passwordController.text)),
                    _hint('At least one number',
                        RegExp(r'\d').hasMatch(_passwordController.text)),
                    _hint('Special character (!@#\$...)',
                        RegExp(r'[!@#\$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]').hasMatch(_passwordController.text)),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05),
            ],
            const SizedBox(height: 24),

            // ── Submit button ────────────────────────────────────────────
            GradientButton(
              expanded: true,
              onPressed: () => _submit(),
              child: const Text('Sign up'),
            ).animate().fadeIn(duration: 300.ms, delay: 420.ms),
            const SizedBox(height: 20),

            // ── Log-in link ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: AppTypography.body(context, size: 13)
                      .copyWith(color: l.mutedForeground),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Log in',
                    style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                        .copyWith(color: AppColors.iris),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 480.ms),
          ],
        ),
      ),
    );
  }

  bool _hasUpper(String s) => RegExp(r'[A-Z]').hasMatch(s);
  bool _hasLower(String s) => RegExp(r'[a-z]').hasMatch(s);

  Widget _hint(String text, bool done) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_off,
               size: 14,
               color: done ? Colors.greenAccent : l.mutedForeground),
          const SizedBox(width: 6),
          Text(text,
            style: AppTypography.body(context, size: 11).copyWith(
              color: done ? l.foreground : l.mutedForeground,
            ),
          ),
        ],
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
            color: color == const Color(0xFF1877F2) ? Colors.transparent : context.lumina.border,
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

/// Renders a Material icon for social login buttons.
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