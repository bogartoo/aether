import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aether_theme.dart';

/// Aether's brand mark — a fractured heart.
class BrokenHeartLogo extends StatelessWidget {
  const BrokenHeartLogo({
    super.key,
    this.size = 40,
    this.animate = true,
  });

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: const _BrokenHeartPainter(),
    );

    if (!animate) return mark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: mark,
    );
  }
}

class _BrokenHeartPainter extends CustomPainter {
  const _BrokenHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final top = h * 0.18;
    final bottom = h * 0.92;

    Path heartPath() {
      final p = Path();
      p.moveTo(cx, bottom);
      p.cubicTo(w * 0.08, h * 0.62, w * 0.02, h * 0.28, w * 0.28, top);
      p.cubicTo(w * 0.40, h * 0.02, cx, h * 0.16, cx, h * 0.28);
      p.cubicTo(cx, h * 0.16, w * 0.60, h * 0.02, w * 0.72, top);
      p.cubicTo(w * 0.98, h * 0.28, w * 0.92, h * 0.62, cx, bottom);
      p.close();
      return p;
    }

    final leftClip = Path()
      ..moveTo(0, 0)
      ..lineTo(cx - w * 0.01, 0)
      ..lineTo(cx - w * 0.06, h * 0.35)
      ..lineTo(cx + w * 0.02, h * 0.52)
      ..lineTo(cx - w * 0.05, h * 0.70)
      ..lineTo(cx + w * 0.01, h)
      ..lineTo(0, h)
      ..close();

    final rightClip = Path()
      ..moveTo(w, 0)
      ..lineTo(cx + w * 0.01, 0)
      ..lineTo(cx - w * 0.06, h * 0.35)
      ..lineTo(cx + w * 0.02, h * 0.52)
      ..lineTo(cx - w * 0.05, h * 0.70)
      ..lineTo(cx + w * 0.01, h)
      ..lineTo(w, h)
      ..close();

    final heart = heartPath();

    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.intersect, heart, leftClip));
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AetherColors.heart, AetherColors.heartDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(w * 0.035, h * 0.01);
    canvas.clipPath(Path.combine(PathOperation.intersect, heart, rightClip));
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFF4D6D), AetherColors.heartDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    // Fracture edge highlight
    final crack = Path()
      ..moveTo(cx - w * 0.01, h * 0.18)
      ..lineTo(cx - w * 0.06, h * 0.35)
      ..lineTo(cx + w * 0.02, h * 0.52)
      ..lineTo(cx - w * 0.05, h * 0.70)
      ..lineTo(cx + w * 0.01, h * 0.90);

    canvas.drawPath(
      crack,
      Paint()
        ..color = AetherColors.foam.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.035)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
