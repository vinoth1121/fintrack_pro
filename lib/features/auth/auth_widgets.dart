import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Shared scaffold for all auth screens — gradient brand header + form card.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  const AuthScaffold({super.key, required this.child, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [l.background, l.surface2.withValues(alpha: 0.5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand logo — the real FinTrack Pro logo
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 72, height: 72,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Color(0x336C5CE7), blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Image.asset('assets/branding/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                Center(
                  child: Text('FinTrack Pro', style: AppTypography.display(context, size: 22).copyWith(
                    foreground: Paint()..shader = AppColors.brandGradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                  ),),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(title, style: AppTypography.heading(context, size: 18)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(subtitle!, style: AppTypography.body(context, size: 13).copyWith(color: l.mutedForeground), textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 32),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Styled text field for auth forms.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  const AuthTextField({
    super.key, required this.controller, required this.label,
    this.hint, this.obscureText = false, this.keyboardType = TextInputType.text,
    this.prefixIcon, this.suffixIcon, this.validator, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(context, size: 12).copyWith(color: l.mutedForeground)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: AppTypography.body(context, size: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: l.surface3.withValues(alpha: 0.4),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: l.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: l.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iris, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

/// Error message banner.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ],),
    );
  }
}
