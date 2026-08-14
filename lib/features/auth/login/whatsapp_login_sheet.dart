import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/toast.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/fintrack_provider.dart';

/// "Continue with WhatsApp" — in reality this is a genuine phone-number +
/// OTP login, using /api/auth/phone/send and /api/auth/phone/verify, which
/// already existed fully working on the backend and in AuthRepository but
/// were never wired to any screen. There is no such thing as an official
/// "Sign in with WhatsApp" OAuth provider (unlike Google/Facebook/Apple),
/// so this is deliberately styled around WhatsApp's phone-first identity
/// rather than pretending to be a Meta OAuth integration.
Future<void> showWhatsAppLoginSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WhatsAppLoginSheet(),
  );
}

class _WhatsAppLoginSheet extends ConsumerStatefulWidget {
  const _WhatsAppLoginSheet();

  @override
  ConsumerState<_WhatsAppLoginSheet> createState() => _WhatsAppLoginSheetState();
}

enum _Step { phone, code }

class _WhatsAppLoginSheetState extends ConsumerState<_WhatsAppLoginSheet> {
  _Step _step = _Step.phone;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _sentToPhone;
  String? _devOtpHint; // backend echoes the code in dev builds — shown so testing doesn't require server-log access

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number, including country code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final otpEcho = await AuthRepository.sendPhoneOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.code;
        _sentToPhone = phone;
        _devOtpHint = otpEcho.isNotEmpty ? otpEcho : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code you received.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AuthRepository.verifyPhoneOtp(phone: _sentToPhone!, code: code);
      if (!mounted) return;
      ref.read(authProvider.notifier).setAuthResult(result);
      await ref.read(fintrackProvider.notifier).syncFromServer();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: l.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: l.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: l.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == _Step.phone ? 'Continue with WhatsApp' : 'Enter your code',
                        style: AppTypography.heading(context, size: 17),
                      ),
                      Text(
                        _step == _Step.phone
                            ? 'We\'ll text a 6-digit code to verify your number'
                            : 'Sent to $_sentToPhone',
                        style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_step == _Step.phone) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]'))],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                onSubmitted: (_) => _sendCode(),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: AppTypography.heading(context, size: 24).copyWith(letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                onSubmitted: (_) => _verifyCode(),
              ),
              if (_devOtpHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Dev mode — your code is $_devOtpHint (the backend prints this to server logs; wire real SMS/WhatsApp delivery before production)',
                    style: AppTypography.body(context, size: 11).copyWith(color: l.mutedForeground),
                  ),
                ),
            ],

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: AppTypography.body(context, size: 12).copyWith(color: AppColors.error)),
              ),

            const SizedBox(height: 20),
            GradientButton(
              onPressed: _loading ? null : (_step == _Step.phone ? _sendCode : _verifyCode),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_step == _Step.phone ? 'Send code' : 'Verify & continue'),
            ),
            if (_step == _Step.code) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => setState(() { _step = _Step.phone; _error = null; }),
                child: const Text('Use a different number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
