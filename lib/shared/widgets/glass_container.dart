import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final Color? borderColor;
  final bool useBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 24,
    this.blur = 12,
    this.opacity = 0.1,
    this.padding = const EdgeInsets.all(20),
    this.border,
    this.borderColor,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    // SECURITY/STABILITY FIX: Disable blur on Windows to prevent "Gray Screen" rendering crashes.
    final bool canBlur = useBlur && !(!kIsWeb && Platform.isWindows);

    if (!canBlur) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        decoration: _buildDecoration(isSolid: true),
        child: child,
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: _buildDecoration(),
            child: child,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration({bool isSolid = false}) {
    return BoxDecoration(
      color: isSolid 
        ? const Color(0xFF1E1E1E).withValues(alpha: 0.95) // Solid fallback
        : Color.fromRGBO(255, 255, 255, opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ??
          Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      boxShadow: [
        // Outer soft shadow
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          spreadRadius: -10,
          offset: const Offset(0, 10),
        ),
        // Inner glow effect
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.05),
          blurRadius: 0,
          spreadRadius: -1,
          offset: const Offset(1, 1),
        ),
      ],
    );
  }
}
