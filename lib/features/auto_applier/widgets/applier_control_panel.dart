import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../providers/linkedin_applier_provider.dart';

/// Bottom control panel for the LinkedIn Auto Applier.
/// Shows status, stats, and action buttons based on the current phase.
class ApplierControlPanel extends StatelessWidget {
  final ApplierState state;
  final VoidCallback onStartAutomation;
  final VoidCallback onPauseAutomation;
  final VoidCallback onStopAutomation;
  final VoidCallback onGenerateSearchTerms;
  final VoidCallback onShowHistory;
  final VoidCallback onConfirmSubmit;
  final void Function(String jobType) onJobTypeChanged;
  final void Function(bool value) onSmartSelectionChanged;
  final void Function(bool value) onChromeModeChanged;

  const ApplierControlPanel({
    super.key,
    required this.state,
    required this.onStartAutomation,
    required this.onPauseAutomation,
    required this.onStopAutomation,
    required this.onGenerateSearchTerms,
    required this.onShowHistory,
    required this.onConfirmSubmit,
    required this.onJobTypeChanged,
    required this.onSmartSelectionChanged,
    required this.onChromeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.adaptiveSpacing(20), 
                context.adaptiveSpacing(16), 
                context.adaptiveSpacing(20), 
                context.adaptiveSpacing(context.isMobile ? 24 : 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Stats Row ──
                  _buildStatsRow(context),
                  SizedBox(height: context.adaptiveSpacing(14)),

                  // ── Action Buttons ──
                  if (!state.isLinkedInLoggedIn && !state.isChromeMode)
                    _buildPreLoginActions()
                  else
                    _buildPostLoginActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobTypeChip(String value, String label, BuildContext context) {
    final isSelected = state.selectedJobType == value;
    final color = value == 'internship' ? AppColors.secondary : AppColors.primary;

    return InkWell(
      onTap: () => onJobTypeChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.adaptiveSpacing(14), 
          vertical: context.adaptiveSpacing(6),
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: context.adaptiveTextSize(11),
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            icon: Icons.check_circle_rounded,
            label: 'SUCCESS',
            value: '${state.todayApplied}',
            color: AppColors.success,
            context: context,
          ),
        ),
        SizedBox(width: context.adaptiveSpacing(10)),
        Expanded(
          child: _buildStatChip(
            icon: Icons.auto_awesome_rounded,
            label: 'TODAY',
            value: '${state.todayTotal}',
            color: AppColors.primary,
            context: context,
          ),
        ),
        SizedBox(width: context.adaptiveSpacing(10)),
        Expanded(
          child: _buildStatChip(
            icon: Icons.public_rounded,
            label: 'TOTAL',
            value: '${state.allTimeTotal}',
            color: AppColors.secondary,
            context: context,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.adaptiveSpacing(12), 
        vertical: context.adaptiveSpacing(10),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.adaptiveIconSize(10), color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: context.adaptiveTextSize(7),
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: context.adaptiveTextSize(16),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreLoginActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.login_rounded, color: AppColors.tertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sign in to LinkedIn above to get started',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostLoginActions(BuildContext context) {
    return Column(
      children: [
        // Job Type Preference & Smart Selection
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                   _buildJobTypeChip('full-time', 'Full-time', context),
                  SizedBox(width: context.adaptiveSpacing(8)),
                  _buildJobTypeChip('internship', 'Internship', context),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Container(width: 1, height: 20, color: AppColors.outline.withValues(alpha: 0.2)),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.useSmartSelection ? Icons.psychology : Icons.psychology_outlined,
                        size: context.adaptiveIconSize(16),
                        color: state.useSmartSelection ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Smart Selection',
                        style: GoogleFonts.inter(
                          fontSize: context.adaptiveTextSize(12),
                          fontWeight: FontWeight.w600,
                          color: state.useSmartSelection ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: state.useSmartSelection,
                          onChanged: onSmartSelectionChanged,
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Container(width: 1, height: 20, color: AppColors.outline.withValues(alpha: 0.2)),
                  SizedBox(width: context.adaptiveSpacing(16)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chrome_reader_mode_rounded,
                        size: context.adaptiveIconSize(16),
                        color: state.isChromeMode ? AppColors.secondary : AppColors.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Chrome Bridge',
                        style: GoogleFonts.inter(
                          fontSize: context.adaptiveTextSize(12),
                          fontWeight: FontWeight.w600,
                          color: state.isChromeMode ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: state.isChromeMode,
                          onChanged: onChromeModeChanged,
                          activeThumbColor: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // AI Search Terms button
        if (state.searchQueries.isEmpty && !state.isLoadingSearchTerms)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGenerateSearchTerms,
                icon: Icon(Icons.auto_awesome, size: context.adaptiveIconSize(18)),
                label: Text(
                  'Generate AI Search Terms',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: context.adaptiveTextSize(14),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(12)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),

        // Main action row
        Row(
          children: [
            if (state.phase == ApplierPhase.submitWaiting)
              Expanded(
                child: _buildSubmitButton(context),
              )
            else
              Expanded(
                child: _buildMainActionButton(context),
              ),
            if (state.isAutomating) ...[
              SizedBox(width: context.adaptiveSpacing(10)),
              // Stop button
              IconButton.filled(
                onPressed: onStopAutomation,
                icon: Icon(Icons.stop_rounded, size: context.adaptiveIconSize(22)),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.2),
                  foregroundColor: AppColors.error,
                  padding: EdgeInsets.all(context.adaptiveSpacing(12)),
                ),
                tooltip: 'Stop',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onConfirmSubmit,
      icon: Icon(Icons.send_rounded, size: context.adaptiveIconSize(22)),
      label: Text(
        'Confirm & Submit',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          fontSize: context.adaptiveTextSize(14),
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(14)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 8,
        shadowColor: AppColors.success.withValues(alpha: 0.5),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds);
  }

  Widget _buildMainActionButton(BuildContext context) {
    final isActive = state.isAutomating;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive ? [] : [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isActive ? onPauseAutomation : onStartAutomation,
        icon: Icon(
          isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: context.adaptiveIconSize(24),
        ),
        label: Text(
          isActive ? 'PAUSE MISSION' : 'START AI MISSION',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: context.adaptiveTextSize(14),
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? AppColors.tertiary
              : AppColors.primary,
          foregroundColor: isActive
              ? AppColors.background
              : Colors.white,
          padding: EdgeInsets.symmetric(vertical: context.adaptiveSpacing(18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 3.seconds, delay: 2.seconds, color: Colors.white.withValues(alpha: 0.1));
  }
}
