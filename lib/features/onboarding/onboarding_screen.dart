import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/widgets.dart' show GradientButton;
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// 4-slide onboarding — welcome / clarity / coach / security.
/// Each slide has a gradient icon tile, title, and body. The user can swipe
/// through slides, tap dots to jump, Continue to advance, or Skip to finish.
/// On finish, calls `setOnboardingDone(true)`; the router then redirects to
/// /dashboard.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  static const _slideCount = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(fintrackProvider.notifier).setOnboardingDone(true);
  }

  void _skipToLogin() {
    ref.read(fintrackProvider.notifier).setOnboardingDone(true);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final l = context.lumina;
    final slides = _slides(t);

    return Scaffold(
      backgroundColor: l.background,
      body: SafeArea(
        child: Column(
          children: [
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slideCount,
                onPageChanged: (i) => setState(() => _step = i),
                itemBuilder: (c, i) => _SlideView(slide: slides[i]),
              ),
            ),
            // Dots + Continue
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slideCount, (i) {
                      final active = i == _step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 28 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? AppColors.iris : l.surface3,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Skip — prominent, above Continue
                  TextButton(
                    onPressed: _skipToLogin,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: Text(
                      t.common.skip,
                      style: AppTypography.body(
                        context,
                        size: 14,
                        weight: FontWeight.w600,
                      ).copyWith(
                        color: AppColors.iris,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.iris.withValues(alpha: 0.5),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  // Continue / Get started
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      onPressed: _next,
                      icon: Icon(
                        _step < _slideCount - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                        size: 18,
                      ),
                      child: Text(
                        _step < _slideCount - 1
                            ? t.common.continue_
                            : t.common.getStarted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Slide> _slides(AppT t) => [
        _Slide(
          icon: Icons.auto_awesome,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.iris, AppColors.cyan],
          ),
          title: t.onboarding.welcomeTitle,
          body: t.onboarding.welcomeBody,
        ),
        _Slide(
          icon: Icons.bar_chart_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cyan, AppColors.success],
          ),
          title: t.onboarding.clarityTitle,
          body: t.onboarding.clarityBody,
        ),
        _Slide(
          icon: Icons.psychology,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.iris, AppColors.info],
          ),
          title: t.onboarding.coachTitle,
          body: t.onboarding.coachBody,
        ),
        _Slide(
          icon: Icons.shield_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.success, AppColors.iris],
          ),
          title: t.onboarding.securityTitle,
          body: t.onboarding.securityBody,
        ),
      ];
}

class _Slide {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gradient icon tile with glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: slide.gradient,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: 2400.ms,
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                  )
                  .fade(duration: 2400.ms, begin: 0.4, end: 0.0),
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: slide.gradient,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55303F9F),
                      blurRadius: 36,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(slide.icon, color: Colors.white, size: 56),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                  ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.display(context, size: 24, weight: FontWeight.bold),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.08, end: 0, duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              slide.body,
              textAlign: TextAlign.center,
              style: AppTypography.body(context, size: 14).copyWith(
                color: l.mutedForeground,
                height: 1.55,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 350.ms)
              .slideY(begin: 0.08, end: 0, duration: 500.ms, delay: 350.ms),
        ],
      ),
    );
  }
}
