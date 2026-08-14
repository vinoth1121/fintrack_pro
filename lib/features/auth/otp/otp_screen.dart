import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../providers/fintrack_provider.dart';

/// OTP verification screen. Used for two flows:
/// - `purpose = 'register'` → on success routes to /dashboard
/// - `purpose = 'forgot_password'` → on success routes back to /login
class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String purpose;
  const OtpScreen({
    super.key,
    required this.email,
    required this.purpose,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _length = 6;
  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_length, (_) => FocusNode());
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    // Wire up backspace handling: when the user hits backspace on an empty
    // cell, move focus to the previous cell (so they can clear it).
    for (var i = 0; i < _length; i++) {
      final idx = i;
      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[idx].text.isEmpty &&
            idx > 0) {
          _focusNodes[idx - 1].requestFocus();
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int i, String value) {
    if (_error != null) setState(() => _error = null);

    // Handle paste of a full code into a single cell.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var j = 0; j < _length && j < digits.length; j++) {
        _controllers[j].text = digits[j];
      }
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty == -1) {
        _focusNodes[_length - 1].unfocus();
      } else {
        _focusNodes[nextEmpty].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty && i < _length - 1) {
      _focusNodes[i + 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length != _length) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final result = await AuthRepository.verifyOtp(
        email: widget.email,
        code: code,
        purpose: widget.purpose,
      );
      if (!mounted) return;
      ref.read(authProvider.notifier).setAuthResult(result);
      await ref.read(fintrackProvider.notifier).syncFromServer();
      if (!mounted) return;
      showAppToast(
        context,
        'Verified successfully',
        kind: ToastKind.success,
      );
      if (widget.purpose == 'forgot_password') {
        context.go('/login');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthRepository.sendOtp(
        email: widget.email,
        purpose: widget.purpose,
      );
      if (!mounted) return;
      showAppToast(
        context,
        'Code resent',
        description: 'A new code has been sent to ${widget.email}.',
        kind: ToastKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not resend code',
        description: e.toString(),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Widget _buildCell(int i) {
    final l = context.lumina;
    return SizedBox(
      width: 56,
      height: 56,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        maxLength: 1,
        style: AppTypography.heading(context, size: 22),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => _onChanged(i, v),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: l.surface3.withValues(alpha: 0.4),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: l.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: l.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code sent to ${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            AuthErrorBanner(message: _error!).animate().fadeIn(duration: 250.ms),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              const count = _length;
              final computed =
                  (constraints.maxWidth - gap * (count - 1)) / count;
              final cellWidth = computed < 56 ? computed : 56.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  count,
                  (i) => SizedBox(
                    width: cellWidth,
                    height: 56,
                    child: _buildCell(i),
                  ),
                ),
              );
            },
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
          const SizedBox(height: 24),
          GradientButton(
            expanded: true,
            loading: _verifying,
            onPressed: _verifying ? null : _verify,
            child: const Text('Verify'),
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive a code?",
                style: AppTypography.body(context, size: 13)
                    .copyWith(color: context.lumina.mutedForeground),
              ),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(
                  _resending ? 'Sending…' : 'Resend code',
                  style: AppTypography.body(context, size: 13, weight: FontWeight.w600)
                      .copyWith(color: AppColors.iris),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms, delay: 160.ms),
        ],
      ),
    );
  }
}
