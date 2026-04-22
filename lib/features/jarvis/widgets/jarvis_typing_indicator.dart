import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

class JarvisTypingIndicator extends StatelessWidget {
  const JarvisTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMinimalPresence(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PROCESSING',
                style: GoogleFonts.inter(
                  color: AppColors.primary.withOpacity(0.5),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1500.ms),
              const SizedBox(height: 6),
              Row(
                children: List.generate(3, (index) => _buildDot(index)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalPresence() {
    return Container(
      width: 2,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scaleY(begin: 0.5, end: 1.5, duration: 600.ms);
  }

  Widget _buildDot(int index) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(
       begin: const Offset(0.5, 0.5),
       end: const Offset(1.5, 1.5),
       duration: 300.ms,
       delay: (index * 150).ms,
     ).fadeIn(delay: (index * 150).ms);
  }
}
