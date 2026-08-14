import 'package:flutter/material.dart';

/// FinTrack Pro Design Tokens
/// Single source of truth for all visual constants.
/// All UI components must reference these tokens — never hardcode values.
abstract final class AppColors {
  // ─── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4B44CC);
  static const Color primaryContainer = Color(0xFF1E1B4B);

  static const Color secondary = Color(0xFF00D4A8);
  static const Color secondaryLight = Color(0xFF5EFFD8);
  static const Color secondaryDark = Color(0xFF00A37F);
  static const Color secondaryContainer = Color(0xFF003D30);

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const Color income = Color(0xFF00D4A8);
  static const Color expense = Color(0xFFFF5252);
  static const Color budget = Color(0xFFFFB300);
  static const Color savings = Color(0xFF6C63FF);

  static const Color success = Color(0xFF00C853);
  static const Color successContainer = Color(0xFF00391A);
  static const Color warning = Color(0xFFFFB300);
  static const Color warningContainer = Color(0xFF3D2A00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorContainer = Color(0xFF3D0000);
  static const Color info = Color(0xFF2196F3);
  static const Color infoContainer = Color(0xFF00244A);

  // ─── Dark Theme Surfaces ───────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF111121);
  static const Color darkCard = Color(0xFF1A1A2E);
  static const Color darkCardElevated = Color(0xFF22223A);
  static const Color darkDivider = Color(0xFF2A2A45);
  static const Color darkBorder = Color(0xFF2E2E4E);

  // ─── Light Theme Surfaces ─────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF8F8FF);
  static const Color lightDivider = Color(0xFFE8E8F5);
  static const Color lightBorder = Color(0xFFDEDEF0);

  // ─── Text Dark ────────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF0F0FF);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);
  static const Color darkTextTertiary = Color(0xFF666680);
  static const Color darkTextDisabled = Color(0xFF444460);

  // ─── Text Light ───────────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0D0D1A);
  static const Color lightTextSecondary = Color(0xFF555570);
  static const Color lightTextTertiary = Color(0xFF8888A0);
  static const Color lightTextDisabled = Color(0xFFBBBBCC);

  // ─── Gradient Presets ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9D97FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF00D4A8), Color(0xFF00F5C8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF8A80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF22223A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A0A14), Color(0xFF1A1040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Chart Colors ─────────────────────────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF6C63FF),
    Color(0xFF00D4A8),
    Color(0xFFFFB300),
    Color(0xFFFF5252),
    Color(0xFF2196F3),
    Color(0xFFE040FB),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
  ];
}

abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  // ─── Display ──────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.22,
  );

  // ─── Headline ─────────────────────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  );

  // ─── Title ────────────────────────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // ─── Label ────────────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ─── Financial Display (custom) ───────────────────────────────────────────
  static const TextStyle amountHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 42,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle amountMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle amountSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );
}

abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // Semantic aliases
  static const double screenPadding = base;
  static const double cardPadding = base;
  static const double sectionGap = xl;
  static const double itemGap = sm;
  static const double formFieldGap = base;
}

abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  // Semantic aliases
  static const double card = base;
  static const double input = md;
  static const double button = md;
  static const double chip = full;
  static const double bottomSheet = xxl;
  static const double dialog = xl;
  static const double avatar = full;
  static const double icon = sm;
}

abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration page = Duration(milliseconds: 350);
  static const Duration splash = Duration(milliseconds: 2500);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve emphasizedDecelerate = Curves.easeOutCubic;
  static const Curve emphasizedAccelerate = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
}

abstract final class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 6;
  static const double overlay = 12;
  static const double modal = 24;
}

abstract final class AppIconSizes {
  static const double xs = 14.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double base = 24.0;
  static const double lg = 28.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
}
