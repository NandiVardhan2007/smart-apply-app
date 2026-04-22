import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';

/// Premium intro card for the LinkedIn Profile Optimizer.
///
/// Explains the feature, shows benefits, and presents a CTA to connect LinkedIn.
class LinkedInIntroCard extends StatelessWidget {
  final VoidCallback onConnect;

  const LinkedInIntroCard({super.key, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Hero icon
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0A66C2).withValues(alpha: 0.2),
                  const Color(0xFF0A66C2).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF0A66C2).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'in',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0A66C2),
                height: 1.0,
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          // Title
          Text(
            'LinkedIn Profile\nOptimizer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  height: 1.15,
                ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          const SizedBox(height: 12),

          Text(
            'AI-powered analysis to boost your profile visibility and attract recruiters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 36),

          // Feature list
          _buildFeatureItem(
            Icons.shield_outlined,
            'Secure & Private',
            'Log in directly to LinkedIn. We never store your credentials.',
            AppColors.success,
            0,
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.auto_awesome,
            'AI-Powered Insights',
            'Get personalized suggestions across 8 profile categories.',
            AppColors.tertiary,
            1,
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.trending_up,
            'Visibility Score',
            'See how your profile ranks and what to improve first.',
            AppColors.primary,
            2,
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            Icons.checklist,
            'Action Plan',
            'Prioritized steps to transform your profile into a recruiter magnet.',
            AppColors.secondary,
            3,
          ),

          const SizedBox(height: 40),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A66C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF0A66C2).withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Connect LinkedIn',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 600.ms)
              .slideY(begin: 0.15),

          const SizedBox(height: 16),

          // Privacy note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 14, color: AppColors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Your login happens inside LinkedIn\'s official page',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms, delay: 700.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    int index,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (300 + index * 80).ms)
        .slideX(begin: 0.08);
  }
}
