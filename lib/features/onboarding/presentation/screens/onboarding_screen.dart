import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _illustrationController;
  late final Animation<double> _illustrationFloat;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Track Every\nPenny with AI',
      subtitle:
          'Automatically categorize your spending and get real-time insights powered by artificial intelligence.',
      gradientColors: [Color(0xFF1A1040), Color(0xFF0A0A14)],
      accentColor: AppColors.primary,
      illustrationType: _IllustrationType.dashboard,
    ),
    _OnboardingData(
      title: 'Smart Budgets\nThat Learn',
      subtitle:
          'FinTrack Pro adapts to your spending habits and creates personalized budgets that actually work for you.',
      gradientColors: [Color(0xFF001A12), Color(0xFF0A0A14)],
      accentColor: AppColors.secondary,
      illustrationType: _IllustrationType.budget,
    ),
    _OnboardingData(
      title: 'Reach Your\nFinancial Goals',
      subtitle:
          'Set savings goals, track subscriptions, scan receipts, and get AI-powered advice to build real wealth.',
      gradientColors: [Color(0xFF1A0A00), Color(0xFF0A0A14)],
      accentColor: AppColors.warning,
      illustrationType: _IllustrationType.goals,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _illustrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _illustrationFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(
        parent: _illustrationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _illustrationController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) context.go(AppRoutes.login);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.slow,
        curve: AppCurves.emphasizedDecelerate,
      );
    } else {
      _onGetStarted();
    }
  }

  void _skip() => _onGetStarted();

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // ── Animated background gradient ───────────────────────────────────
          AnimatedContainer(
            duration: AppDurations.slow,
            curve: AppCurves.emphasizedDecelerate,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── Page content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: AnimatedOpacity(
                      opacity: _currentPage < _pages.length - 1 ? 1 : 0,
                      duration: AppDurations.normal,
                      child: TextButton(
                        onPressed: _skip,
                        child: Text(
                          'Skip',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Illustrations
                Expanded(
                  flex: 5,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, i) {
                      return AnimatedBuilder(
                        animation: _illustrationFloat,
                        builder: (context, _) {
                          return Transform.translate(
                            offset: Offset(0, _illustrationFloat.value),
                            child: _OnboardingIllustration(
                              type: _pages[i].illustrationType,
                              accentColor: _pages[i].accentColor,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Text content
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (i) => _PageDot(
                              isActive: i == _currentPage,
                              color: page.accentColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Title
                        AnimatedSwitcher(
                          duration: AppDurations.normal,
                          child: Text(
                            page.title,
                            key: ValueKey(_currentPage),
                            style: AppTypography.headlineLarge.copyWith(
                              color: AppColors.darkTextPrimary,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.base),

                        // Subtitle
                        AnimatedSwitcher(
                          duration: AppDurations.normal,
                          child: Text(
                            page.subtitle,
                            key: ValueKey('sub_$_currentPage'),
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.darkTextSecondary,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const Spacer(),

                        // CTA Button
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xl,
                          ),
                          child: _OnboardingButton(
                            label: _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Continue',
                            color: page.accentColor,
                            onTap: _nextPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Model ──────────────────────────────────────────────────────────────

class _OnboardingData {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final _IllustrationType illustrationType;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.illustrationType,
  });
}

enum _IllustrationType { dashboard, budget, goals }

// ─── Illustration ─────────────────────────────────────────────────────────────

class _OnboardingIllustration extends StatelessWidget {
  final _IllustrationType type;
  final Color accentColor;

  const _OnboardingIllustration({
    required this.type,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: switch (type) {
          _IllustrationType.dashboard => _DashboardIllustration(accent: accentColor),
          _IllustrationType.budget => _BudgetIllustration(accent: accentColor),
          _IllustrationType.goals => _GoalsIllustration(accent: accentColor),
        },
      ),
    );
  }
}

class _DashboardIllustration extends StatelessWidget {
  final Color accent;
  const _DashboardIllustration({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 310,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card mock
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 8,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.darkTextTertiary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    height: 20,
                    width: 130,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Mini chart mock
            Row(
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: [30.0, 50.0, 35.0, 65.0, 45.0, 75.0, 55.0][i],
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: i == 5 ? 0.8 : 0.25,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Transaction rows mock
            for (int i = 0; i < 3; i++) ...[
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.darkCardElevated,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 7,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.darkTextTertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          width: 60,
                          decoration: BoxDecoration(
                            color: AppColors.darkBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 10,
                    width: 50,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? AppColors.income.withValues(alpha: 0.4)
                          : AppColors.expense.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              if (i < 2) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetIllustration extends StatelessWidget {
  final Color accent;
  const _BudgetIllustration({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.darkTextSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            // Budget progress bars
            for (int i = 0; i < 4; i++) ...[
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.chartPalette[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          width: 70,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.darkTextTertiary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: [0.7, 0.45, 0.9, 0.3][i],
                            backgroundColor: AppColors.darkBorder,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.chartPalette[i],
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < 3) const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.base),
            // Donut chart mock
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent,
                    width: 14,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsIllustration extends StatelessWidget {
  final Color accent;
  const _GoalsIllustration({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            // Savings goal cards mock
            for (int i = 0; i < 3; i++) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.darkCardElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.darkBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.chartPalette[i].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 7,
                            width: 80,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.darkTextSecondary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: [0.65, 0.3, 0.85][i],
                              backgroundColor: AppColors.darkBorder,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.chartPalette[i],
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2) const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.base),
            // AI insight card mock
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: accent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          color: accent.withValues(alpha: 0.5),
                          margin: const EdgeInsets.only(bottom: 4),
                        ),
                        Container(
                          height: 6,
                          width: 120,
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ],
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
}

// ─── Page Dot Indicator ───────────────────────────────────────────────────────

class _PageDot extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _PageDot({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: AppCurves.emphasizedDecelerate,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : AppColors.darkBorder,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

// ─── CTA Button ──────────────────────────────────────────────────────────────

class _OnboardingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OnboardingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.button),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
