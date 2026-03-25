import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static final _pages = [
    const _OnboardingData(
      title: 'Pool money\ntogether',
      subtitle:
          'Start or join a chama, fundraiser, or community drive. Set a target, invite your people, and watch contributions come in.',
      illustration: _IllustrationType.pool,
      accent: AppColors.sage,
    ),
    _OnboardingData(
      title: 'Pay with\nM-Pesa or Airtel',
      subtitle:
          'Contribute instantly using M-Pesa STK Push or Airtel Money. Your phone buzzes, you enter your PIN — done.',
      illustration: _IllustrationType.payment,
      accent: AppColors.mpesaGreen,
    ),
    const _OnboardingData(
      title: 'Track every\nshilling',
      subtitle:
          'See exactly how much has been raised, who contributed, and how close you are to the goal. Transparent by design.',
      illustration: _IllustrationType.track,
      accent: AppColors.gold,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go(AppRoutes.register);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 12),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.green,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.forest
                              : AppColors.sand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Primary CTA
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                  const SizedBox(height: 12),

                  // Already have account
                  if (isLast)
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: Text(
                        'Already have an account? Sign in',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.green,
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
}

// ── Onboarding page ───────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          _OnboardingIllustration(type: data.illustration, accent: data.accent),
          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            style: AppTextStyles.h1.copyWith(color: AppColors.forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.green,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Illustrations ─────────────────────────────────────────────────────────────

enum _IllustrationType { pool, payment, track }

class _OnboardingIllustration extends StatelessWidget {
  final _IllustrationType type;
  final Color accent;
  const _OnboardingIllustration({required this.type, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(140, 140),
          painter: _IllustrationPainter(type: type, accent: accent),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final _IllustrationType type;
  final Color accent;
  const _IllustrationPainter({required this.type, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _IllustrationType.pool:
        _drawPool(canvas, size);
      case _IllustrationType.payment:
        _drawPayment(canvas, size);
      case _IllustrationType.track:
        _drawTrack(canvas, size);
    }
  }

  void _drawPool(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.forest.withValues(alpha: 0.08);
    final fgPaint = Paint()..color = AppColors.forest;
    final accentP = Paint()..color = accent;

    // Three people silhouettes
    final positions = [
      Offset(size.width * 0.25, size.height * 0.38),
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.75, size.height * 0.38),
    ];
    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      final paint = i == 1 ? fgPaint : (Paint()..color = AppColors.green);
      // Head
      canvas.drawCircle(p, 10, paint);
      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(p.dx, p.dy + 22), width: 18, height: 22),
          const Radius.circular(9),
        ),
        paint,
      );
    }

    // Arrow converging to center coin
    final arrowPaint = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.5, size.height * 0.72);
    for (final p in positions) {
      canvas.drawLine(
        Offset(p.dx, p.dy + 35),
        center,
        arrowPaint,
      );
    }

    // Coin
    canvas.drawCircle(center, 16, accentP);
    final symPaint = Paint()..color = AppColors.cream;
    final tp = TextPainter(
      text: TextSpan(
        text: 'KES',
        style: TextStyle(color: AppColors.cream, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawPayment(Canvas canvas, Size size) {
    final phonePaint = Paint()..color = AppColors.forest;
    final screenPaint = Paint()..color = AppColors.cream;
    final accentP = Paint()..color = accent;

    // Phone body
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.48),
        width: 56,
        height: 90,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(phoneRect, phonePaint);

    // Screen
    final screenRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.46),
      width: 44,
      height: 66,
    );
    canvas.drawRect(screenRect, screenPaint);

    // M-Pesa green band
    canvas.drawRect(
      Rect.fromLTWH(screenRect.left, screenRect.top, screenRect.width, 20),
      accentP,
    );

    // Signal waves
    final wavePaint = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.78, size.height * 0.35),
          width: i * 18.0,
          height: i * 18.0,
        ),
        -1.2,
        1.0,
        false,
        wavePaint..color = accent.withValues(alpha: (0.9 - i * 0.2).clamp(0.2, 0.9)),
      );
    }
  }

  void _drawTrack(Canvas canvas, Size size) {
    final barBg = Paint()..color = AppColors.sand;
    final barFg = Paint()..color = accent;
    final labelPaint = Paint()..color = AppColors.forest;

    final bars = [0.85, 0.55, 0.70, 0.40];
    final barW = size.width * 0.14;
    final spacing = size.width * 0.17;
    final startX = size.width * 0.12;
    final maxH = size.height * 0.55;
    final baseY = size.height * 0.78;

    for (int i = 0; i < bars.length; i++) {
      final x = startX + i * spacing;
      final fullH = maxH;
      final fillH = maxH * bars[i];

      // Background bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - fullH, barW, fullH),
          const Radius.circular(4),
        ),
        barBg,
      );
      // Filled bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - fillH, barW, fillH),
          const Radius.circular(4),
        ),
        barFg,
      );
    }

    // Progress label
    final tp = TextPainter(
      text: TextSpan(
        text: '85%',
        style: AppTextStyles.amountSmall.copyWith(
          color: AppColors.forest,
          fontSize: 22,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width * 0.5 - tp.width / 2, size.height * 0.08),
    );

    final subTp = TextPainter(
      text: TextSpan(
        text: 'funded',
        style: AppTextStyles.caption.copyWith(color: AppColors.green),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(
      canvas,
      Offset(size.width * 0.5 - subTp.width / 2, size.height * 0.22),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Data class ────────────────────────────────────────────────────────────────

class _OnboardingData {
  final String title;
  final String subtitle;
  final _IllustrationType illustration;
  final Color accent;
  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.accent,
  });
}
