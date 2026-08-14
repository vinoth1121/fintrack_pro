import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Lumina Material 3 Theme — dark default (premium fintech) + light.
class AppTheme {
  AppTheme._();

  static const _radius = 16.0;

  static ThemeData dark() => _base(Brightness.dark);
  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final fg = isDark ? AppColors.darkForeground : AppColors.lightForeground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final surface3 = isDark ? AppColors.darkSurface3 : AppColors.lightSurface3;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.lightMutedForeground;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary = isDark ? AppColors.iris : AppColors.irisLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.iris,
      brightness: brightness,
      primary: primary,
      secondary: AppColors.cyan,
      surface: surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: fg,
    );

    final baseText = GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).copyWith(
      bodyLarge: TextStyle(color: fg, fontSize: 14),
      bodyMedium: TextStyle(color: fg, fontSize: 13),
      bodySmall: TextStyle(color: muted, fontSize: 12),
      titleLarge: GoogleFonts.plusJakartaSans(color: fg, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: GoogleFonts.plusJakartaSans(color: fg, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleSmall: GoogleFonts.plusJakartaSans(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelSmall: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: baseText,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: fg, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: fg),
      ),
      cardTheme: CardThemeData(
        color: surface2.withValues(alpha: isDark ? 0.7 : 0.78),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface3.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : muted,),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.iris : surface3,),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        modalBarrierColor: Colors.black54,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface3,
        contentTextStyle: TextStyle(color: fg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: IconThemeData(color: fg),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.95),
        indicatorColor: AppColors.iris.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? primary : muted,
          ),),
      ),
    );
  }
}
