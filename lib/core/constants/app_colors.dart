import 'package:flutter/material.dart';

class AppColors {
  // Base Colors
  static const Color background = Color(0xFF131316);
  static const Color surface = Color(0xFF1F1F22);
  static const Color surfaceLow = Color(0xFF1B1B1E);
  static const Color surfaceHigh = Color(0xFF2A2A2D);
  static const Color surfaceHighest = Color(0xFF353438);
  
  // Brand Colors
  static const Color primary = Color(0xFF3B82F6); // Electric Blue
  static const Color secondary = Color(0xFF8B5CF6); // Violet
  static const Color tertiary = Color(0xFFFBBF24); // Gold
  
  // Text Colors
  static const Color onBackground = Color(0xFFE4E1E6);
  static const Color onSurface = Color(0xFFC2C6D6);
  static const Color onPrimary = Color(0xFF002E6A);
  
  // Accent & Utilities
  static const Color outline = Color(0xFF424754);
  static const Color error = Color(0xFFFFB4AB);
  static const Color warning = Color(0xFFFFD180); // Amber/Orange for warnings
  static const Color success = Color(0xFF4ADE80);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF4D8EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF),
      Color(0x0FFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
