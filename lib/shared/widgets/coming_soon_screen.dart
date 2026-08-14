import 'package:flutter/material.dart';
import '../../core/constants/app_tokens.dart';
import 'shell/main_shell.dart';

/// Temporary placeholder for screens not yet built.
/// Shows the menu button (drawer access) and a "coming soon" state
/// so the app remains fully navigable during development.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => ShellScaffoldData.of(context)?.openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: color.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '$title — Coming Soon',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This module is under active development.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
