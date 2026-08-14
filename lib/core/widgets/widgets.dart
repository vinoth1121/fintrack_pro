import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Glassmorphic card with hairline highlight.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool strong, glow, hover;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const GlassCard({
    super.key, required this.child, this.padding, this.margin,
    this.radius = 20, this.strong = false, this.glow = false, this.hover = false,
    this.onTap, this.boxShadow, this.border,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: (strong ? l.surface3 : l.surface2).withValues(alpha: strong ? 0.82 : 0.7),
        border: border ?? Border.all(color: l.border, width: 1),
        boxShadow: boxShadow ??
          (glow ? [const BoxShadow(color: Color(0x59303F9F), blurRadius: 24, spreadRadius: 0)] : null),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.heading(context, size: 16)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: AppTypography.body(context, size: 12).copyWith(color: context.lumina.mutedForeground)),
                ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;
  final bool expanded;
  const GradientButton({super.key, required this.child, this.onPressed, this.icon, this.loading = false, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppColors.brandGradient,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else if (icon != null)
                  Padding(padding: const EdgeInsets.only(right: 8), child: IconTheme(data: const IconThemeData(color: Colors.white, size: 16), child: icon!)),
                DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Widget? icon;
  const GhostButton({super.key, required this.child, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: l.surface2.withValues(alpha: 0.7),
        border: Border.all(color: l.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: icon),
                DefaultTextStyle.merge(
                  style: TextStyle(color: l.foreground, fontWeight: FontWeight.w500, fontSize: 14),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  final double value;
  final String currency;
  final double size;
  final FontWeight weight;
  final bool signed, compact;
  final Color? color;
  const AmountText({super.key, required this.value, this.currency = 'INR', this.size = 20, this.weight = FontWeight.w600, this.signed = false, this.compact = false, this.color});

  @override
  Widget build(BuildContext context) {
    final sym = _currencySymbol(currency);
    final abs = value.abs();
    String body;
    if (compact && abs >= 1000000) {
      body = '${(abs / 1000000).toStringAsFixed(abs >= 10000000 ? 1 : 2)}M';
    } else if (compact && abs >= 1000) {
      body = '${(abs / 1000).toStringAsFixed(abs >= 100000 ? 1 : 2)}K';
    } else {
      body = abs.toStringAsFixed(abs == abs.roundToDouble() ? 0 : 2);
      // add thousands separators
      final parts = body.split('.');
      parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+\d$)'), (m) => '${m[1]},');
      body = parts.join('.');
    }
    final sign = value < 0 ? '-' : (signed ? '+' : '');
    return Text('$sign$sym$body', style: AppTypography.amount(context, size: size, weight: weight).copyWith(color: color));
  }
}

String _currencySymbol(String code) => const {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'AED': 'د.إ', 'AUD': 'A\$', 'CAD': 'C\$'}[code] ?? '$code ';

class StatTile extends StatelessWidget {
  final String label;
  final Widget value;
  final String? delta;
  final bool? deltaPositive;
  final Widget? icon;
  final String accent; // iris|cyan|green|amber|red
  const StatTile({super.key, required this.label, required this.value, this.delta, this.deltaPositive, this.icon, this.accent = 'iris'});

  Color _accentColor() => const {'iris': AppColors.iris, 'cyan': AppColors.cyan, 'green': AppColors.success, 'amber': AppColors.warning, 'red': AppColors.error}[accent] ?? AppColors.iris;

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: AppTypography.label(context, size: 10).copyWith(letterSpacing: 1.2, color: l.mutedForeground)),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: [_accentColor().withValues(alpha: 0.3), _accentColor().withValues(alpha: 0.05)]),
                  ),
                  child: IconTheme(data: IconThemeData(color: _accentColor(), size: 16), child: icon!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(style: AppTypography.amount(context, size: 22, weight: FontWeight.bold), child: value),
          if (delta != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${(deltaPositive ?? true) ? "▲" : "▼"} $delta',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: (deltaPositive ?? true) ? AppColors.success : AppColors.error),),
            ),
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double value; // 0-100
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;
  const ProgressRing({super.key, required this.value, this.size = 72, this.stroke = 7, this.color = AppColors.iris, this.child});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value: value, stroke: stroke, color: color, track: l.border),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value, stroke;
  final Color color, track;
  _RingPainter({required this.value, required this.stroke, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    canvas.drawCircle(center, radius, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    final sweep = (value.clamp(0, 100) / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, sweep, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class EmptyState extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? description;
  final Widget? action;
  const EmptyState({super.key, this.icon, required this.title, this.description, this.action});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: l.border, style: BorderStyle.solid, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: AppColors.brandGradient),
              child: IconTheme(data: const IconThemeData(color: Colors.white, size: 24), child: icon!),
            ),
          Text(title, style: AppTypography.heading(context, size: 15)),
          if (description != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(description!, textAlign: TextAlign.center, style: AppTypography.body(context, size: 12).copyWith(color: l.mutedForeground))),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 20), child: action!),
        ],
      ),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width, height;
  final double radius;
  const ShimmerBox({super.key, this.width = double.infinity, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), color: l.surface3.withValues(alpha: 0.5)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: l.foreground.withValues(alpha: 0.05));
  }
}

class GradientPill extends StatelessWidget {
  final Widget child;
  const GradientPill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [AppColors.iris.withValues(alpha: 0.22), AppColors.cyan.withValues(alpha: 0.18)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), child: child),
    );
  }
}

/// Animated entrance wrapper.
Widget fadeIn(Widget child, {Duration delay = Duration.zero}) =>
  child.animate().fadeIn(duration: 500.ms, delay: delay).slideY(begin: 0.05, end: 0, duration: 500.ms, delay: delay);
