import 'package:flutter/material.dart';

import 'hrtbrkr_theme.dart';

/// Brand mark — broken heart (two halves with a visible gap).
class HrtbrkrLogo extends StatelessWidget {
  const HrtbrkrLogo({
    super.key,
    this.size = 40,
    this.iconSize,
  });

  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final glyph = iconSize ?? size * 0.58;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [HrtbrkrColors.mint, HrtbrkrColors.cyan],
        ),
        boxShadow: [
          BoxShadow(
            color: HrtbrkrColors.mint.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            spreadRadius: size > 60 ? 2 : 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: glyph,
        height: glyph,
        child: const CustomPaint(painter: _BrokenHeartPainter()),
      ),
    );
  }
}

class _BrokenHeartPainter extends CustomPainter {
  const _BrokenHeartPainter();

  Path _leftHalf(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.48, h * 0.28);
    path.cubicTo(w * 0.48, h * 0.16, w * 0.38, h * 0.04, w * 0.26, h * 0.12);
    path.cubicTo(w * -0.02, h * 0.28, w * 0.08, h * 0.58, w * 0.42, h * 0.90);
    path.lineTo(w * 0.38, h * 0.72);
    path.lineTo(w * 0.50, h * 0.58);
    path.lineTo(w * 0.36, h * 0.44);
    path.lineTo(w * 0.48, h * 0.28);
    path.close();
    return path;
  }

  Path _rightHalf(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.52, h * 0.28);
    path.cubicTo(w * 0.52, h * 0.16, w * 0.62, h * 0.04, w * 0.74, h * 0.12);
    path.cubicTo(w * 1.02, h * 0.28, w * 0.92, h * 0.58, w * 0.58, h * 0.90);
    path.lineTo(w * 0.62, h * 0.72);
    path.lineTo(w * 0.50, h * 0.58);
    path.lineTo(w * 0.64, h * 0.44);
    path.lineTo(w * 0.52, h * 0.28);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(-size.width * 0.03, 0);
    canvas.drawPath(_leftHalf(size), paint);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width * 0.03, 0);
    canvas.drawPath(_rightHalf(size), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
