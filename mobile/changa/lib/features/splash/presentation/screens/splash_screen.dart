import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _dotsController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  bool _navigated = false;
  ProviderSubscription<AuthState>? _authSub; // ← nullable, safe to dispose

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupAuthListener();
    _startSequence();
  }

  void _setupAuthListener() {
    // addPostFrameCallback ensures ref is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authSub = ref.listenManual<AuthState>(
        authNotifierProvider,
        (previous, next) {
          if (next is AuthAuthenticated ||
              next is AuthUnauthenticated ||
              next is AuthError) {
            _navigate();
          }
        },
      );
    });
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textController.forward();

    // Wait long enough for auth to resolve in most cases
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;

    // Timer expired — try to navigate now.
    // If auth is still loading, the listener will handle it when it resolves.
    _navigate();
  }

  Future<void> _navigate() async {
    // Guard: only navigate once, and only when mounted
    if (_navigated || !mounted) return;

    final authState = ref.read(authNotifierProvider);

    if (authState is AuthAuthenticated) {
      _navigated = true;
      context.go(AppRoutes.home);
      return;
    }

    if (authState is AuthUnauthenticated || authState is AuthError) {
      _navigated = true;
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      debugPrint('>>> onboarding_done: $done');
      if (!mounted) return;
      context.go(done ? AppRoutes.login : AppRoutes.onboarding);
      return;
    }

    // AuthInitial or AuthLoading — do nothing, listener will fire
  }

  @override
  void dispose() {
    _authSub?.close(); // ← safe null-aware close
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NO ref.listen here — handled entirely by listenManual in initState
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: Stack(
        children: [
          const _GeometricBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  child: const _LogoMark(),
                  builder: (context, child) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'changa',
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.cream,
                            fontSize: 40,
                            letterSpacing: -1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'contribute together',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mint,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textOpacity,
              child: _LoadingDots(controller: _dotsController),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cream.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: const Center(
        child: CustomPaint(size: Size(54, 54), painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..color = AppColors.cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    final leafPaint = Paint()
      ..color = AppColors.sage
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.fill;

    final cx = size.width * 0.52;
    final cy = size.height * 0.48;
    final r = size.width * 0.35;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.55,
      4.9,
      false,
      arcPaint,
    );

    final bx = cx + r * 0.82;
    final by = cy + r * 0.82;
    canvas.drawPath(
      Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx + 7, by - 9, bx - 2, by - 13)
        ..quadraticBezierTo(bx - 9, by - 5, bx, by),
      leafPaint,
    );

    final tx = cx + r * 0.82;
    final ty = cy - r * 0.82;
    canvas.drawPath(
      Path()
        ..moveTo(tx, ty)
        ..quadraticBezierTo(tx + 6, ty - 6, tx + 1, ty - 9)
        ..quadraticBezierTo(tx - 4, ty - 2, tx, ty),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GeometricBackground extends StatelessWidget {
  const _GeometricBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(child: CustomPaint(painter: _GeoBgPainter())),
    );
  }
}

class _GeoBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = AppColors.green.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(size.width + 40, -40), 140, p1);

    final p2 = Paint()..color = AppColors.green.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(-60, size.height + 20), 160, p2);

    final p3 = Paint()..color = AppColors.sage.withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.55), 90, p3);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = ((controller.value + i * 0.33) % 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.25, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: const SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}