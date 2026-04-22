import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/utils/responsive_utils.dart';
import '../models/linkedin_optimization_result.dart';

/// Displays the complete LinkedIn optimization results in a premium UI.
///
/// Includes:
/// - Animated score ring with grade
/// - Category breakdown grid
/// - Strengths & weaknesses lists
/// - Prioritized improvement plan
class OptimizationResultView extends StatefulWidget {
  final LinkedInOptimizationResult result;
  final VoidCallback onNewScan;

  const OptimizationResultView({
    super.key,
    required this.result,
    required this.onNewScan,
  });

  @override
  State<OptimizationResultView> createState() => _OptimizationResultViewState();
}

class _OptimizationResultViewState extends State<OptimizationResultView>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreAnimController;

  @override
  void initState() {
    super.initState();
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return CenteredContent(
      maxWidth: 1100,
      child: CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onNewScan,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Re-analyze'),
                ),
              ],
            ),
          ),
        ),

        // Score Ring
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _buildScoreRing(r.overallScore, r.overallGrade, r.summary),
          ),
        ),

        // Categories
        if (r.categories.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child:
                  _buildSectionTitle('Category Breakdown', Icons.analytics_outlined),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildCategoryCard(r.categories[index], index),
                childCount: r.categories.length,
              ),
            ),
          ),
        ],

        // Strengths
        if (r.strengths.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: _buildSectionTitle(
                  '✅ Strengths', Icons.emoji_events_outlined),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildBulletList(r.strengths, AppColors.success),
            ),
          ),
        ],

        // Weaknesses
        if (r.weaknesses.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: _buildSectionTitle(
                  '⚠️ Areas to Improve', Icons.warning_amber_outlined),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildBulletList(r.weaknesses, AppColors.tertiary),
            ),
          ),
        ],

        // Improvement Plan
        if (r.improvementPlan.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: _buildSectionTitle(
                  '🚀 Improvement Plan', Icons.rocket_launch_outlined),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: _buildImprovementCard(
                    r.improvementPlan[index], index),
              ),
              childCount: r.improvementPlan.length,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    ));
  }

  // ─── Score Ring ───
  Widget _buildScoreRing(int score, String grade, String summary) {
    return GlassContainer(
      child: Column(
        children: [
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _scoreAnimController,
            builder: (context, child) {
              final animatedScore =
                  (score * _scoreAnimController.value).round();
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    score: score,
                    progress: _scoreAnimController.value,
                    color: _scoreColor(score),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$animatedScore',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: _scoreColor(score),
                          ),
                        ),
                        Text(
                          grade,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _scoreColor(score).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'LinkedIn Visibility Score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  // ─── Category Card ───
  Widget _buildCategoryCard(OptimizationCategory cat, int index) {
    final color = _scoreColor(cat.score);
    final iconData = _categoryIcon(cat.icon);

    return GestureDetector(
      onTap: () => _showCategoryDetail(cat),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, size: 18, color: color),
                const Spacer(),
                Text(
                  cat.grade,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: cat.score / 100,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cat.score}/100',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()

        .fadeIn(duration: 400.ms, delay: (200 + index * 80).ms)
        .slideY(begin: 0.1, end: 0);

  }

  void _showCategoryDetail(OptimizationCategory cat) {
    final color = _scoreColor(cat.score);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(_categoryIcon(cat.icon), color: color, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${cat.score}/100 · ${cat.grade}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Findings
                  if (cat.findings.isNotEmpty) ...[
                    const Text(
                      'Findings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cat.findings.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(color: AppColors.outline)),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onSurface
                                        .withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 16),

                  // Suggestions
                  if (cat.suggestions.isNotEmpty) ...[
                    Text(
                      'Suggestions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...cat.suggestions.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: color.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onSurface
                                        .withValues(alpha: 0.85),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Improvement Card ───
  Widget _buildImprovementCard(ImprovementAction item, int index) {
    Color priorityColor;
    switch (item.priority.toUpperCase()) {
      case 'HIGH':
        priorityColor = const Color(0xFFFF6B6B);
        break;
      case 'MEDIUM':
        priorityColor = AppColors.tertiary;
        break;
      default:
        priorityColor = AppColors.success;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: priorityColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  item.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (item.impact.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 14, color: AppColors.success.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.impact,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (item.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.details,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (200 + index * 100).ms)
        .slideX(begin: 0.05);
  }

  // ─── Helpers ───

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBulletList(List<String> items, Color accent) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: entry.key < items.length - 1 ? 10 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  static Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.tertiary;
    return const Color(0xFFFF6B6B);
  }

  static IconData _categoryIcon(String iconName) {
    switch (iconName) {
      case 'title':
        return Icons.title;
      case 'person':
        return Icons.person_outline;
      case 'work':
        return Icons.work_outline;
      case 'school':
        return Icons.school_outlined;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'checklist':
        return Icons.checklist;
      case 'search':
        return Icons.search;
      default:
        return Icons.info_outline;
    }
  }
}

/// Custom painter for the animated score ring.
class _ScoreRingPainter extends CustomPainter {
  final int score;
  final double progress;
  final Color color;

  _ScoreRingPainter({
    required this.score,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppColors.surfaceHigh;
    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: 0.6), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweepAngle = 2 * pi * (score / 100) * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );

    // Glow dot at the end
    if (progress > 0.1) {
      final dotAngle = -pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(dotCenter, 6, glowPaint);
      canvas.drawCircle(dotCenter, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.score != score;
}
