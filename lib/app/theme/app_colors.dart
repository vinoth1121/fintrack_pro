import 'package:flutter/material.dart';

/// Lumina Design System — Color Tokens
/// Faithfully ported from the web app's globals.css (oklch → sRGB hex approximations).
class AppColors {
  AppColors._();

  // Brand
  static const iris = Color(0xFF6C5CE7);
  static const irisLight = Color(0xFF5A4BD1);
  static const cyan = Color(0xFF00D2FF);
  static const cyanLight = Color(0xFF00B8E6);

  // Semantic
  static const success = Color(0xFF00E676);
  static const successLight = Color(0xFF00C853);
  static const warning = Color(0xFFFFB74D);
  static const warningLight = Color(0xFFF5A623);
  static const error = Color(0xFFFF5252);
  static const errorLight = Color(0xFFE53935);
  static const info = Color(0xFF448AFF);

  // Charts
  static const chart1 = iris;
  static const chart2 = cyan;
  static const chart3 = success;
  static const chart4 = warning;
  static const chart5 = info;
  static const chart6 = Color(0xFFFF6FB5);

  // Dark theme surfaces
  static const darkBackground = Color(0xFF0D0F14);
  static const darkSurface = Color(0xFF161922);
  static const darkSurface2 = Color(0xFF1E2230);
  static const darkSurface3 = Color(0xFF262B3D);
  static const darkForeground = Color(0xFFF0F2F7);
  static const darkMutedForeground = Color(0xFF9BA1B7);
  static const darkBorder = Color(0x1FFFFFFF);

  // Light theme surfaces
  static const lightBackground = Color(0xFFFAFBFD);
  static const lightSurface = Color(0xFFF0F2F7);
  static const lightSurface2 = Color(0xFFE6E9F0);
  static const lightSurface3 = Color(0xFFDDE1EB);
  static const lightForeground = Color(0xFF1A1C24);
  static const lightMutedForeground = Color(0xFF6B7280);
  static const lightBorder = Color(0x1A1A1C24);

  // Gradients
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iris, cyan],
  );
  static const brandGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [irisLight, cyanLight],
  );
}

/// Resolved colors for the current brightness.
class LuminaColors {
  final Brightness brightness;
  LuminaColors(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  Color get background => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surface2 => isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
  Color get surface3 => isDark ? AppColors.darkSurface3 : AppColors.lightSurface3;
  Color get foreground => isDark ? AppColors.darkForeground : AppColors.lightForeground;
  Color get mutedForeground => isDark ? AppColors.darkMutedForeground : AppColors.lightMutedForeground;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get card => surface2.withValues(alpha: isDark ? 0.7 : 0.78);
  Color get primary => isDark ? AppColors.iris : AppColors.irisLight;
  Color get primaryForeground => const Color(0xFFF8FAFC);
}

extension LuminaContext on BuildContext {
  LuminaColors get lumina => LuminaColors(Theme.of(this).brightness);
}
