import 'package:flutter/material.dart';
import '../core/theme.dart';

class NeonBackground extends StatelessWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.2,
          colors: [
            Color(0xFF1C1200),
            LuchiiColors.bgDeep,
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A subtle top ambient glow widget for use as an overlay.
class GoldAmbientGlow extends StatelessWidget {
  const GoldAmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -80,
      left: 0,
      right: 0,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.0,
            colors: [
              LuchiiColors.gold.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
