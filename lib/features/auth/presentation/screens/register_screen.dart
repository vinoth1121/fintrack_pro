import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    _passwordController.addListener(_evaluatePasswordStrength);
  }

  void _evaluatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final state = ref.read(registerProvider);
    if (!state.acceptedTerms) {
      AppSnackbar.warning(context, 'Please accept the Terms & Privacy Policy to continue.');
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref.read(registerProvider.notifier).register(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Account created! Please verify your email.');
      context.push(AppRoutes.otpVerification, extra: _emailController.text.trim());
    } else {
      final failure = ref.read(registerProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create account',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Start your journey to financial clarity',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Full name
                  AppTextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    label: 'Full name',
                    hint: 'Alex Johnson',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.person_outline_rounded,
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Enter your full name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Email
                  AppTextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    label: 'Email address',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.email_outlined,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Password
                  AppTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    hint: '••••••••',
                    obscureText: state.obscurePassword,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: state.obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onSuffixIconTap: () =>
                        ref.read(registerProvider.notifier).togglePasswordVisibility(),
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (_passwordStrength < 0.5) {
                        return 'Password is too weak — add uppercase, numbers, or symbols';
                      }
                      return null;
                    },
                  ),

                  // Password strength indicator
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordStrengthBar(strength: _passwordStrength),
                  ],

                  const SizedBox(height: AppSpacing.base),

                  // Confirm password
                  AppTextField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmFocus,
                    label: 'Confirm password',
                    hint: '••••••••',
                    obscureText: state.obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: state.obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onSuffixIconTap: () => ref
                        .read(registerProvider.notifier)
                        .toggleConfirmPasswordVisibility(),
                    onSubmitted: (_) => _onRegister(),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Terms checkbox
                  _TermsCheckbox(
                    accepted: state.acceptedTerms,
                    onToggle: () =>
                        ref.read(registerProvider.notifier).toggleTerms(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Register button
                  AppPrimaryButton(
                    label: 'Create Account',
                    isLoading: state.isLoading,
                    onTap: _onRegister,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Login link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Password Strength Bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final double strength;

  const _PasswordStrengthBar({required this.strength});

  String get _label {
    if (strength <= 0.25) return 'Weak';
    if (strength <= 0.5) return 'Fair';
    if (strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color get _color {
    if (strength <= 0.25) return AppColors.error;
    if (strength <= 0.5) return AppColors.warning;
    if (strength <= 0.75) return AppColors.info;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Text(
                _label,
                key: ValueKey(_label),
                style: AppTypography.labelSmall.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: List.generate(4, (i) {
            final filled = (i + 1) <= (strength * 4).ceil();
            return Expanded(
              child: AnimatedContainer(
                duration: AppDurations.normal,
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? _color : AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Terms Checkbox ──────────────────────────────────────────────────────────

class _TermsCheckbox extends StatelessWidget {
  final bool accepted;
  final VoidCallback onToggle;

  const _TermsCheckbox({required this.accepted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accepted ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: accepted ? AppColors.primary : AppColors.darkBorder,
                width: 1.5,
              ),
            ),
            child: accepted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.darkTextSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
