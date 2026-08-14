import 'package:flutter/material.dart';
import '../../../core/constants/app_tokens.dart';

/// Centralized snackbar system.
/// All feedback messages in the app go through this — never ScaffoldMessenger directly.
abstract class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Color iconColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(AppSpacing.base),
          content: _SnackbarContent(
            message: message,
            backgroundColor: backgroundColor,
            icon: icon,
            iconColor: iconColor,
            action: action,
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.success,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline_rounded,
      duration: const Duration(seconds: 4),
    );
  }

  static void warning(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.black87,
    );
  }

  static void info(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.darkCard,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
    );
  }
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final SnackBarAction? action;

  const _SnackbarContent({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: AppIconSizes.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: action!.onPressed,
              child: Text(
                action!.label,
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
