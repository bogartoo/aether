import 'package:flutter/material.dart';

import 'aether_theme.dart';

/// Brand mark — broken heart.
class AetherLogo extends StatelessWidget {
  const AetherLogo({
    super.key,
    this.size = 40,
    this.iconSize,
  });

  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final glyph = iconSize ?? size * 0.48;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AetherColors.mint, AetherColors.cyan],
        ),
        boxShadow: [
          BoxShadow(
            color: AetherColors.mint.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            spreadRadius: size > 60 ? 2 : 0,
          ),
        ],
      ),
      child: Icon(
        Icons.heart_broken_rounded,
        size: glyph,
        color: Colors.black,
      ),
    );
  }
}
