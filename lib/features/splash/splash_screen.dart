import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../providers/fintrack_provider.dart';
import '../../providers/auth_provider.dart';

/// Splash screen — animated brand logo, gradient wordmark, tagline, loading dots.
/// After ~1.9s it sets `booted=true` and routes to onboarding (or dashboard if
/// onboarding was already completed). Navigation is guarded by [_splashNavigated]
/// so it fires exactly once even if this widget is remounted (the GoRouter is
/// recreated whenever boot/auth state changes during startup).
bool _splashNavigated = false;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('[Splash] mounted');
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      ref.read(fintrackProvider.notifier).setBooted(true);
      // Auth status is resolved by AuthNotifier; router redirect handles routing.
      // Brief delay lets the auth provider restore the session.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _splashNavigated) return;
        _splashNavigated = true;
        final authStatus = ref.read(authStatusProvider);
        final onboardingDone = ref.read(fintrackProvider.select((s) => s.onboardingDone));
        debugPrint('[Splash] navigating (authStatus=$authStatus, onboardingDone=$onboardingDone)');
        if (authStatus == AuthStatus.authenticated) {
          // Cold restart with an existing session: pull the latest server
          // state instead of trusting the local SharedPreferences cache.
          unawaited(ref.read(fintrackProvider.notifier).syncFromServer());
          context.go(onboardingDone ? '/dashboard' : '/onboarding');
        } else if (!onboardingDone) {
          context.go('/onboarding');
        } else {
          context.go('/login');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Scaffold(
      backgroundColor: l.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              AppColors.iris.withValues(alpha: 0.18),
              AppColors.cyan.withValues(alpha: 0.08),
              l.background,
            ],
            stops: const [0.0, 0.4, 0.85],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with pulsing glow
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow halo — soft radial glow, fully transparent at the
                    // edge (not a hard-edged gradient box), so it reads as
                    // ambient light instead of a dark ring/blob.
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.iris.withValues(alpha: 0.45),
                            AppColors.cyan.withValues(alpha: 0.25),
                            AppColors.cyan.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: 2200.ms,
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1.1, 1.1),
                        )
                        .fade(
                          duration: 2200.ms,
                          begin: 0.9,
                          end: 0.5,
                        ),
                    // Logo tile — the real FinTrack Pro logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x66303F9F),
                              blurRadius: 28,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/branding/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 700.ms)
                        .scale(
                          duration: 900.ms,
                          curve: Curves.easeOutCubic,
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1, 1),
                        )
                        .rotate(
                          duration: 900.ms,
                          curve: Curves.easeOutCubic,
                          begin: -0.35,
                          end: 0,
                        ),
                  ],
                ),
                const SizedBox(height: 24),
                // Brand wordmark with gradient on "Pro"
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'FinTrack',
                      style: AppTypography.display(
                        context,
                        size: 30,
                        weight: FontWeight.bold,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.brandGradient.createShader(bounds),
                      child: Text(
                        ' Pro',
                        style: AppTypography.display(
                          context,
                          size: 30,
                          weight: FontWeight.bold,
                        ).copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                      delay: 400.ms,
                    ),
                const SizedBox(height: 8),
                Text(
                  'Lumina · AI Personal Finance',
                  style: AppTypography.body(context, size: 13).copyWith(
                    color: l.mutedForeground,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 700.ms),
                const SizedBox(height: 36),
                // Loading dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.iris,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(
                          duration: 1000.ms,
                          delay: (i * 180).ms,
                          begin: 0.25,
                          end: 1.0,
                        );
                  }),
                ).animate().fadeIn(duration: 400.ms, delay: 1000.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
