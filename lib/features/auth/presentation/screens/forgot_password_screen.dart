import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

class _ForgotPasswordState {
  final bool isLoading;
  final bool isSuccess;
  final Failure? failure;
  const _ForgotPasswordState({
    this.isLoading = false,
    this.isSuccess = false,
    this.failure,
  });
  _ForgotPasswordState copyWith({bool? isLoading, bool? isSuccess, Failure? failure, bool clear = false}) =>
      _ForgotPasswordState(
        isLoading: isLoading ?? this.isLoading,
        isSuccess: isSuccess ?? this.isSuccess,
        failure: clear ? null : failure ?? this.failure,
      );
}

class _ForgotPasswordNotifier extends StateNotifier<_ForgotPasswordState> {
  final AuthRepositoryImpl _repo;
  _ForgotPasswordNotifier(this._repo) : super(const _ForgotPasswordState());

  Future<bool> sendReset(String email) async {
    state = state.copyWith(isLoading: true, clear: true);
    final result = await _repo.sendPasswordReset(email);
    return result.fold(
      (f) { state = state.copyWith(isLoading: false, failure: f); return false; },
      (_) { state = state.copyWith(isLoading: false, isSuccess: true); return true; },
    );
  }
}

final _forgotPasswordProvider =
    StateNotifierProvider.autoDispose<_ForgotPasswordNotifier, _ForgotPasswordState>((ref) {
  return _ForgotPasswordNotifier(ref.watch(authRepositoryProvider));
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(_forgotPasswordProvider.notifier)
        .sendReset(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Reset code sent to your email.');
      context.push(AppRoutes.otpVerification, extra: _emailController.text.trim());
    } else {
      final f = ref.read(_forgotPasswordProvider).failure;
      if (f != null) AppSnackbar.error(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_forgotPasswordProvider);
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
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 26),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Reset password',
                      style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.darkTextPrimary, fontWeight: FontWeight.w800,),),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Enter your registered email and we'll send you a secure reset code.",
                    style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.darkTextSecondary, height: 1.5,),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.email_outlined,
                    onSubmitted: (_) => _onSubmit(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: 'Send Reset Code',
                    leadingIcon: Icons.send_rounded,
                    isLoading: state.isLoading,
                    onTap: _onSubmit,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary),
                          children: [
                            const TextSpan(text: 'Remember your password? '),
                            TextSpan(text: 'Sign in',
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.primary, fontWeight: FontWeight.w700,),),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
