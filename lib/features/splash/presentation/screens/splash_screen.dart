import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/network/secure_storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _glowController;

  // ── Logo Animations ────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoRotate;

  // ── Text Animations ────────────────────────────────────────────────────────
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // ── Glow Animation ────────────────────────────────────────────────────────
  late final Animation<double> _glowRadius;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSequence();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Logo: scale from 0.6 → 1.0 with spring feel
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Logo: fade in
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Logo: subtle rotate from -5° → 0°
    _logoRotate = Tween<double>(begin: -0.087, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // Text: fade in
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Text: slide up
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Ambient glow pulse
    _glowRadius = Tween<double>(begin: 80, end: 120).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startSequence() async {
    // Phase 1: Logo appears
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _logoController.forward();

    // Phase 2: Text fades in
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _textController.forward();

    // Phase 3: Hold on screen
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Phase 4: Navigate
    await _navigate();
  }

  Future<void> _navigate() async {
    final storage = ref.read(secureStorageServiceProvider);
    final token = await storage.getAccessToken();

    if (!mounted) return;

    if (token != null) {
      // Validate token freshness → in production, decode JWT exp
      context.go(AppRoutes.dashboard);
    } else {
      // Check if user has seen onboarding
      // TODO: read SharedPreferences onboardingCompleted flag
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // ── Ambient background gradient ────────────────────────────────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1A1040),
                    AppColors.darkBackground,
                  ],
                ),
              ),
            ),
          ),

          // ── Animated glow behind logo ──────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return Container(
                  width: _glowRadius.value * 2,
                  height: _glowRadius.value * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: _glowRadius.value,
                        spreadRadius: _glowRadius.value * 0.3,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _logoRotate.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: const _FinTrackLogo(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Brand name + tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, _) {
                    return SlideTransition(
                      position: _textSlide,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: const _BrandText(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Bottom loading indicator ──────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, _) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: const _LoadingDots(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logo Widget ─────────────────────────────────────────────────────────────

class _FinTrackLogo extends StatelessWidget {
  const _FinTrackLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: _LogoIcon(),
      ),
    );
  }
}

class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) {
    // Custom painted logo — a stylized "FT" monogram with upward trend line
    return CustomPaint(
      size: const Size(52, 52),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Stylized upward chart line — the core brand mark
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.78)
      ..lineTo(size.width * 0.25, size.height * 0.55)
      ..lineTo(size.width * 0.45, size.height * 0.65)
      ..lineTo(size.width * 0.70, size.height * 0.30)
      ..lineTo(size.width * 0.95, size.height * 0.15);

    canvas.drawPath(path, paint);

    // Arrowhead at end of trend line
    final arrowPath = Path()
      ..moveTo(size.width * 0.95, size.height * 0.15)
      ..lineTo(size.width * 0.78, size.height * 0.16)
      ..moveTo(size.width * 0.95, size.height * 0.15)
      ..lineTo(size.width * 0.92, size.height * 0.30);

    canvas.drawPath(arrowPath, paint);

    // Dot data points
    for (final point in [
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.45, size.height * 0.65),
      Offset(size.width * 0.70, size.height * 0.30),
    ]) {
      canvas.drawCircle(point, 3.5, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Brand Text ──────────────────────────────────────────────────────────────

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'FinTrack',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: ' Pro',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Your AI Financial Companion',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.darkTextTertiary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Animated Loading Dots ────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
      _controllers.add(controller);
      _animations.add(animation);

      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, _) {
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: _animations[i].value),
              ),
            );
          },
        );
      }),
    );
  }
}
