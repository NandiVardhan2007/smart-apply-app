import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AnimatedAmbientBackground extends StatefulWidget {
  const AnimatedAmbientBackground({super.key});

  @override
  State<AnimatedAmbientBackground> createState() => _AnimatedAmbientBackgroundState();
}

class _AnimatedAmbientBackgroundState extends State<AnimatedAmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AmbientGlowPainter(
            primaryColor: AppColors.primary,
            secondaryColor: AppColors.secondary,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double animationValue;

  _AmbientGlowPainter({
    required this.primaryColor,
    required this.secondaryColor,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Drifting Orb 1
    final orb1Offset = Offset(
      size.width * (0.8 + 0.1 * math.sin(animationValue * 2 * math.pi)),
      size.height * (0.1 + 0.05 * math.cos(animationValue * 2 * math.pi)),
    );
    canvas.drawCircle(
      orb1Offset,
      150,
      paint..color = primaryColor.withValues(alpha: 0.06),
    );

    // Drifting Orb 2
    final orb2Offset = Offset(
      size.width * (0.2 + 0.15 * math.cos(animationValue * 4 * math.pi)),
      size.height * (0.7 + 0.1 * math.sin(animationValue * 4 * math.pi)),
    );
    canvas.drawCircle(
      orb2Offset,
      200,
      paint..color = secondaryColor.withValues(alpha: 0.05),
    );

    // Drifting Orb 3
    final orb3Offset = Offset(
      size.width * (0.9 + 0.05 * math.sin(animationValue * 6 * math.pi)),
      size.height * (0.9 + 0.05 * math.cos(animationValue * 6 * math.pi)),
    );
    canvas.drawCircle(
      orb3Offset,
      120,
      paint..color = primaryColor.withValues(alpha: 0.04),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
