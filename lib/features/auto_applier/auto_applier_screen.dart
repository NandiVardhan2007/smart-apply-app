import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_utils.dart';
import 'providers/linkedin_applier_provider.dart';
import 'widgets/applier_control_panel.dart';
import 'widgets/history_sheet.dart';

/// Production-ready LinkedIn Auto Job Applier screen.
/// Displays a live mission console for Chrome-based automation.
class AutoApplierScreen extends ConsumerStatefulWidget {
  const AutoApplierScreen({super.key});

  @override
  ConsumerState<AutoApplierScreen> createState() => _AutoApplierScreenState();
}

class _AutoApplierScreenState extends ConsumerState<AutoApplierScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  final ScrollController _consoleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(applierProvider.notifier).loadStats();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_consoleScrollController.hasClients) {
      _consoleScrollController.animateTo(
        _consoleScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            _buildTopBar(state, context),

            // ── Main Content: Mission Console ──
            Expanded(
              child: Container(
                margin: EdgeInsets.all(context.adaptiveSpacing(16)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: state.automationLogs.isEmpty
                      ? _buildEmptyConsole()
                      : _buildLiveConsole(state),
                ),
              ),
            ),

            // ── Control Panel ──
            CenteredContent(
              maxWidth: 1200,
              child: ApplierControlPanel(
                state: state,
                onStartAutomation: () async {
                  await ref.read(applierProvider.notifier).startAutomation();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Chrome Bridge Initialized',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success.withValues(alpha: 0.9),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                onPauseAutomation: () {
                  ref.read(applierProvider.notifier).pauseAutomation();
                },
                onStopAutomation: () {
                  ref.read(applierProvider.notifier).stopAutomation();
                },
                onGenerateSearchTerms: () {
                  ref.read(applierProvider.notifier).generateSearchTerms();
                },
                onShowHistory: () => _showHistorySheet(),
                onConfirmSubmit: () {
                  ref.read(applierProvider.notifier).confirmSubmit();
                },
                onJobTypeChanged: (type) {
                  ref.read(applierProvider.notifier).setSelectedJobType(type);
                },
                onSmartSelectionChanged: (value) {
                  ref.read(applierProvider.notifier).setUseSmartSelection(value);
                },
                onChromeModeChanged: (value) {
                  ref.read(applierProvider.notifier).setChromeMode(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ApplierState state, BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.adaptiveSpacing(16),
            vertical: context.adaptiveSpacing(12),
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    size: context.adaptiveIconSize(16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.white70,
                  constraints: BoxConstraints.tightFor(
                    width: context.adaptiveSpacing(38),
                    height: context.adaptiveSpacing(38),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: context.adaptiveSpacing(16)),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMART APPLY AI',
                      style: GoogleFonts.manrope(
                        fontSize: context.adaptiveTextSize(11),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          _getStatusText(state).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: context.adaptiveTextSize(14),
                            color: state.phase == ApplierPhase.error
                                ? AppColors.error
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (state.isAutomating) ...[
                          const SizedBox(width: 8),
                          _buildPulseIndicator(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              _buildStatBadge(
                context: context,
                icon: Icons.check_circle_rounded,
                label: 'APPLIED',
                value: state.todayApplied.toString(),
                color: AppColors.success,
              ),
              SizedBox(width: context.adaptiveSpacing(8)),
              _buildStatBadge(
                context: context,
                icon: Icons.flash_on_rounded,
                label: 'TOTAL',
                value: state.todayTotal.toString(),
                color: AppColors.primary,
              ),
              SizedBox(width: context.adaptiveSpacing(8)),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Colors.white70, size: 20),
                onPressed: () {
                  final allLogs = state.automationLogs.join('\n');
                  Clipboard.setData(ClipboardData(text: allLogs));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copied to clipboard')),
                  );
                },
                tooltip: 'Copy Logs',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return FadeTransition(
      opacity: _pulseController,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary,
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(ApplierState state) {
    if (state.errorMessage != null) return 'TACTICAL FAILURE';
    return switch (state.phase) {
      ApplierPhase.idle => 'Systems Standby',
      ApplierPhase.loggingIn => 'Awaiting Login',
      ApplierPhase.loggedIn => 'Target Locked',
      ApplierPhase.generatingTerms => 'Synthesizing Search Matrix',
      ApplierPhase.browsing => 'Mission Control Ready',
      ApplierPhase.searching => 'Scanning Job Perimeter',
      ApplierPhase.jobOpened => 'Analyzing Opportunity',
      ApplierPhase.easyApplyDetected => 'Target Vulnerability Found',
      ApplierPhase.formDetected => 'Neural Uplink Active',
      ApplierPhase.questionDetected => 'AI Reasoning Required',
      ApplierPhase.autofillReady => 'Payload Prepared',
      ApplierPhase.reviewReady => 'Finalizing Verification',
      ApplierPhase.submitWaiting => 'Confirmation Required',
      ApplierPhase.submitted => 'Mission Success',
      ApplierPhase.error => 'Tactical Failure',
    };
  }

  Widget _buildStatBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.adaptiveSpacing(10),
        vertical: context.adaptiveSpacing(6),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: context.adaptiveIconSize(12)),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.spaceMono(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: context.adaptiveTextSize(14),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.5),
              fontSize: context.adaptiveTextSize(8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConsole() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal, size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'AWAITING MISSION START',
            style: GoogleFonts.spaceMono(
              color: AppColors.primary.withValues(alpha: 0.5),
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Initialize Chrome Bridge to see live AI logs',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveConsole(ApplierState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _consoleScrollController,
      padding: EdgeInsets.all(context.adaptiveSpacing(16)),
      itemCount: state.automationLogs.length,
      itemBuilder: (context, index) {
        final log = state.automationLogs[index];
        bool isError = log.contains('❌') || log.toLowerCase().contains('error');
        bool isSuccess = log.contains('✅') || log.toLowerCase().contains('success');
        bool isInfo = log.contains('🚀') || log.contains('🔄') || log.contains('🤖');

        Color textColor = Colors.white70;
        if (isError) textColor = Colors.redAccent;
        if (isSuccess) textColor = AppColors.success;
        if (isInfo) textColor = AppColors.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            log,
            style: GoogleFonts.spaceMono(
              color: textColor,
              fontSize: context.adaptiveTextSize(12),
              height: 1.4,
            ),
          ),
        );
      },
    );
  }

  void _showHistorySheet() {
    ref.read(applierProvider.notifier).loadHistory();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(applierProvider);
          return HistorySheet(applications: state.applicationHistory);
        },
      ),
    );
  }
}
