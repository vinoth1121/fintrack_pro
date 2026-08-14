import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late final AnimationController _animController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  String get _currentOtp =>
      _controllers.map((c) => c.text).join();

  bool get _isComplete => _currentOtp.length == _otpLength;

  void _onDigitEntered(int index, String value) {
    if (value.isEmpty) {
      // Backspace — move focus back
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }

    // Handle paste of full OTP
    if (value.length == _otpLength) {
      for (int i = 0; i < _otpLength; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes[_otpLength - 1].requestFocus();
      setState(() {});
      return;
    }

    // Single digit — advance focus
    _controllers[index].text = value[value.length - 1];
    if (index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    setState(() {});
  }

  Future<void> _onVerify() async {
    if (!_isComplete) return;
    FocusScope.of(context).unfocus();

    final success = await ref.read(otpProvider.notifier).verifyOtp(
      email: widget.email,
      otp: _currentOtp,
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Email verified! Welcome to FinTrack Pro.');
      context.go(AppRoutes.dashboard);
    } else {
      // Shake animation on error
      _animController.forward(from: 0);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() {});
      final failure = ref.read(otpProvider).failure;
      if (failure != null) AppSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),

            // Header
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Check your email',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.darkTextSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "We've sent a 6-digit code to\n"),
                  TextSpan(
                    text: widget.email,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // OTP input boxes
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final dx = _shake.value < 0.5
                    ? _shake.value * 16 - 8
                    : (1 - _shake.value) * 16 - 8;
                return Transform.translate(
                  offset: Offset(dx * (1 - _shake.value), 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_otpLength, (i) {
                  return _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (v) => _onDigitEntered(i, v),
                    onBackspace: () {
                      if (_controllers[i].text.isEmpty && i > 0) {
                        _controllers[i - 1].clear();
                        _focusNodes[i - 1].requestFocus();
                        setState(() {});
                      }
                    },
                  );
                }),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Verify button
            AppPrimaryButton(
              label: 'Verify Email',
              isLoading: state.isLoading,
              isDisabled: !_isComplete,
              onTap: _isComplete ? _onVerify : null,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Resend section
            Center(
              child: state.resendCountdown > 0
                  ? RichText(
                      text: TextSpan(
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Resend code in '),
                          TextSpan(
                            text: '${state.resendCountdown}s',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : state.isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        )
                      : GestureDetector(
                          onTap: () =>
                              ref.read(otpProvider.notifier).resendOtp(widget.email),
                          child: RichText(
                            text: TextSpan(
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.darkTextSecondary,
                              ),
                              children: [
                                const TextSpan(text: "Didn't receive it? "),
                                TextSpan(
                                  text: 'Resend',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual OTP Box ───────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _hasFocus = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: _hasFocus
            ? AppColors.primaryContainer
            : hasValue
                ? AppColors.darkCardElevated
                : AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _hasFocus
              ? AppColors.primary
              : hasValue
                  ? AppColors.darkBorder
                  : AppColors.darkDivider,
          width: _hasFocus ? 1.5 : 1,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.onBackspace();
          }
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6, // Allow paste
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w800,
          ),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
