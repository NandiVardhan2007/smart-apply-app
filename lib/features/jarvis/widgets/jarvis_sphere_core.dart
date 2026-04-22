import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../jarvis_models.dart';

class JarvisSphereCore extends StatefulWidget {
  final JarvisChatStatus status;
  final double size;

  const JarvisSphereCore({
    super.key,
    required this.status,
    this.size = 300,
  });

  @override
  State<JarvisSphereCore> createState() => _JarvisSphereCoreState();
}

class _JarvisSphereCoreState extends State<JarvisSphereCore>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Point3D> _points;
  final int _pointCount = 500; // High density as per reference

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _generateSphericalPoints();
  }

  void _generateSphericalPoints() {
    _points = [];
    final phi = math.pi * (3 - math.sqrt(5)); // Golden angle

    for (int i = 0; i < _pointCount; i++) {
        final y = 1 - (i / (_pointCount - 1)) * 2; // y goes from 1 to -1
        final radius = math.sqrt(1 - y * y); // radius at y

        final theta = phi * i; // golden angle increment

        final x = math.cos(theta) * radius;
        final z = math.sin(theta) * radius;

        _points.add(_Point3D(x, y, z));
    }
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
          size: Size(widget.size, widget.size),
          painter: HolographicPointPainter(
            points: _points,
            rotation: _controller.value,
            status: widget.status,
            color: _getStatusColor(),
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case JarvisChatStatus.recording:
        return AppColors.warning;
      case JarvisChatStatus.thinking:
      case JarvisChatStatus.typing:
        return AppColors.secondary;
      case JarvisChatStatus.speaking:
        return AppColors.primary;
      case JarvisChatStatus.error:
        return AppColors.error;
      default:
        return const Color(0xFF00E5FF); // Bright Cyan for Idle/Default
    }
  }
}

class _Point3D {
  final double x, y, z;
  _Point3D(this.x, this.y, this.z);
}

class HolographicPointPainter extends CustomPainter {
  final List<_Point3D> points;
  final double rotation;
  final JarvisChatStatus status;
  final Color color;

  HolographicPointPainter({
    required this.points,
    required this.rotation,
    required this.status,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;

    // Time-based animations
    final double angleY = rotation * 2 * math.pi * 2; // Horizontal rotation
    final double angleX = rotation * 2 * math.pi * 0.5; // Slow vertical drift
    
    // Pseudo-Spectral Audio Visualization (Simulation)
    double pulse = 1.0;
    double agitation = 0.0;
    
    if (status == JarvisChatStatus.speaking) {
      // Fractal Noise simulation using 4 different octaves at prime frequencies
      // for a "Spiky" audio amplitude appearance
      double wave1 = math.sin(rotation * 2 * math.pi * 42); // High freq jitter
      double wave2 = math.sin(rotation * 2 * math.pi * 17); // Mid freq "Vowel" pulse
      double wave3 = math.sin(rotation * 2 * math.pi * 8);  // Slow "Sentential" wave
      double wave4 = math.sin(rotation * 2 * math.pi * 125); // Ultra-high holographic flicker
      
      // Combine for a complex amplitude envelope
      double amplitude = (wave1 * 0.4 + wave2 * 0.3 + wave3 * 0.3).abs();
      
      // "Shrink closer and back to normal" logic
      // Pulse will fluctuate between 0.7 (shrunk) and 1.1 (expanded)
      pulse = 0.75 + (amplitude * 0.35); 
      
      agitation = 0.12 * amplitude + (wave4 * 0.02); // Add holographic "sparks" at peaks
    } else if (status == JarvisChatStatus.thinking) {
      pulse = 0.82 + 0.18 * (math.sin(rotation * 2 * math.pi * 5)).abs();
    }

    final renderedPoints = <_ProjectedPoint>[];

    for (var p in points) {
      // 1. Rotate around Y axis
      double x1 = p.x * math.cos(angleY) - p.z * math.sin(angleY);
      double z1 = p.x * math.sin(angleY) + p.z * math.cos(angleY);
      
      // 2. Rotate around X axis for tilt
      double y2 = p.y * math.cos(angleX) - z1 * math.sin(angleX);
      double z2 = p.y * math.sin(angleX) + z1 * math.cos(angleX);
      
      // 3. Project to 2D with dynamic agitation
      // Add jitter to front-facing points during speech for "Reactive" energy
      double jitter = agitation * (z2 > 0 ? z2 : 0);
      final screenX = center.dx + (x1 + jitter * math.cos(rotation * 100)) * radius * pulse;
      final screenY = center.dy + (y2 + jitter * math.sin(rotation * 100)) * radius * pulse;
      
      // 4. Perspective/Depth shading
      final depth = (z2 + 1) / 2; 
      
      double pOpacity = 0.1 + (depth * 0.9);
      // Brighten front points significantly during speech surges
      if (status == JarvisChatStatus.speaking && pulse > 1.02) {
        pOpacity = (pOpacity + 0.15).clamp(0.0, 1.0);
      }

      renderedPoints.add(_ProjectedPoint(
        offset: Offset(screenX, screenY),
        z: z2,
        opacity: pOpacity,
        size: 0.8 + (depth * 2.2),
      ));
    }

    // Sort by Z to handle overlaps (though for points it's less critical than for spheres)
    renderedPoints.sort((a, b) => a.z.compareTo(b.z));

    final paint = Paint()..style = PaintingStyle.fill;
    
    for (var rp in renderedPoints) {
      // Point glow
      paint.color = color.withOpacity(rp.opacity * 0.8);
      canvas.drawCircle(rp.offset, rp.size, paint);
      
      // Optional: Add a "Bloom" pixel for high-intensity front points
      if (rp.z > 0.7) {
        paint.color = Colors.white.withOpacity(rp.opacity * 0.5);
        canvas.drawCircle(rp.offset, rp.size * 0.4, paint);
      }
    }
    
    // Add atmospheric outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.15),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    
    canvas.drawCircle(center, radius * 1.5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant HolographicPointPainter oldDelegate) => true;
}

class _ProjectedPoint {
  final Offset offset;
  final double z;
  final double opacity;
  final double size;

  _ProjectedPoint({
    required this.offset,
    required this.z,
    required this.opacity,
    required this.size,
  });
}
