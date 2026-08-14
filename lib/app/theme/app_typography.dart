import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lumina Typography — Plus Jakarta Sans (display), Inter (body), Space Grotesk (amounts).
class AppTypography {
  AppTypography._();

  static TextStyle display(BuildContext context, {double size = 28, FontWeight weight = FontWeight.bold}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.3,
      height: 1.2,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }

  static TextStyle heading(BuildContext context, {double size = 18, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.2,
      height: 1.3,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }

  static TextStyle body(BuildContext context, {double size = 14, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.1,
      height: 1.5,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }

  static TextStyle label(BuildContext context, {double size = 12, FontWeight weight = FontWeight.w500}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.3,
      height: 1.4,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );
  }

  /// Monetary amounts — tabular numerals, distinctive.
  static TextStyle amount(BuildContext context, {double size = 20, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.3,
      height: 1.3,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }
}
