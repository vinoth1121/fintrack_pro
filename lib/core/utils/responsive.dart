import 'package:flutter/material.dart';

/// Responsive scaling utilities for mobile fit. Uses screen width as base.
class Resp {
  final BuildContext context;

  Resp(this.context);

  /// The available width (screen width minus safe area / padding).
  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;
  bool get isSmall => width < 380;
  bool get isMedium => width >= 380 && width < 600;
  bool get isWide => width >= 700;

  /// Scale a font size proportionally (min 12, caps at design size).
  double font(double designSize) {
    if (designSize <= 12) return designSize;
    final scale = (width / 430).clamp(0.72, 1.0);
    return (designSize * scale).roundToDouble().clamp(12.0, designSize);
  }

  /// Scale a dimension (padding, height, radius).
  double dim(double designSize) {
    final scale = (width / 430).clamp(0.72, 1.0);
    return (designSize * scale).roundToDouble().clamp(8.0, designSize);
  }

  /// Scale a circle / ring size.
  double ring(double designSize) {
    final scale = (width / 430).clamp(0.65, 1.0);
    return (designSize * scale).roundToDouble().clamp(24.0, designSize);
  }

  /// Scale chart height.
  double chart(double designHeight) {
    final scale = (width / 430).clamp(0.55, 1.0);
    return (designHeight * scale).roundToDouble().clamp(120.0, designHeight);
  }

  /// Grid count for stat tiles (always 2 on mobile).
  int get statGridColumns => isWide ? 4 : 2;

  /// Grid count for goals.
  int get goalGridColumns => isWide ? 4 : 2;
}