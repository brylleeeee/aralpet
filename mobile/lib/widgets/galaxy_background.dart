
import 'dart:math' as math;

import 'package:flutter/material.dart';

class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});

  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _GalaxyPainter(
              animation: _controller,
              reduceMotion: reduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter({
    required this.animation,
    required this.reduceMotion,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final bool reduceMotion;

  static final List<_Star> _stars = _createStars();

  static List<_Star> _createStars() {
    final random = math.Random(42);

    return List.generate(85, (index) {
      return _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 0.5 + random.nextDouble() * 1.3,
        speed: 0.08 + random.nextDouble() * 0.22,
        phase: random.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep navy galaxy background.
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF080D22),
          Color(0xFF111632),
          Color(0xFF1A1640),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, background);

    // Subtle purple atmosphere.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7954DB).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.65, size.height * 0.3),
          radius: size.width * 0.85,
        ),
      );

    canvas.drawRect(rect, glow);

    final progress = reduceMotion ? 0.0 : animation.value;

    // Falling and twinkling stars.
    for (final star in _stars) {
      final x = star.x * size.width;

      final y = ((star.y + progress * star.speed) % 1.0) *
          size.height;

      final twinkle = 0.65 +
          0.35 *
              math.sin(
                progress * math.pi * 4 + star.phase,
              ).abs();

      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFB5CAFF),
          const Color(0xFFE8D7FF),
          star.x,
        )!.withValues(alpha: twinkle * 0.8);

      canvas.drawCircle(
        Offset(x, y),
        star.radius,
        paint,
      );
    }

    if (!reduceMotion) {
      _drawShootingStars(canvas, size, progress);
    }
  }

  void _drawShootingStars(
    Canvas canvas,
    Size size,
    double progress,
  ) {
    // Two occasional shooting-star passes per animation cycle.
    _drawShootingStar(
      canvas,
      size,
      progress,
      start: 0.12,
      end: 0.23,
      origin: const Offset(0.12, 0.08),
    );

    _drawShootingStar(
      canvas,
      size,
      progress,
      start: 0.61,
      end: 0.72,
      origin: const Offset(0.55, 0.02),
    );
  }

  void _drawShootingStar(
    Canvas canvas,
    Size size,
    double progress, {
    required double start,
    required double end,
    required Offset origin,
  }) {
    if (progress < start || progress > end) return;

    final t = (progress - start) / (end - start);
    final fade = math.sin(t * math.pi).clamp(0.0, 1.0);

    final head = Offset(
      (origin.dx + t * 0.45) * size.width,
      (origin.dy + t * 0.3) * size.height,
    );

    final tail = head - const Offset(55, 38);

    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF87C9FF).withValues(alpha: fade * 0.9),
        ],
      ).createShader(Rect.fromPoints(tail, head))
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tail, head, trailPaint);

    canvas.drawCircle(
      head,
      2.2,
      Paint()
        ..color = Colors.white.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) {
    return oldDelegate.reduceMotion != reduceMotion;
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
}
