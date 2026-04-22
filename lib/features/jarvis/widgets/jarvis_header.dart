import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../jarvis_models.dart';

class JarvisHeader extends StatelessWidget implements PreferredSizeWidget {
  final JarvisChatStatus status;
  final VoidCallback onBack;
  final VoidCallback onTune;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleLive;
  final VoidCallback onToggleDeepThink;
  final bool isVoiceEnabled;
  final bool isLiveMode;
  final bool isDeepThinkEnabled;

  const JarvisHeader({
    super.key,
    required this.status,
    required this.onBack,
    required this.onTune,
    required this.onToggleVoice,
    required this.onToggleLive,
    required this.onToggleDeepThink,
    required this.isVoiceEnabled,
    required this.isLiveMode,
    required this.isDeepThinkEnabled,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, 
                  color: Colors.white, 
                  size: context.adaptiveIconSize(20)),
        onPressed: onBack,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'JARVIS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: context.adaptiveTextSize(16),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 8),
              _buildPulseIndicator(),
            ],
          ),
          _buildMinimalStatusText(context),
        ],
      ),
      actions: [
        _buildMinimalActionIcons(context),
      ],
    );
  }

  Widget _buildPulseIndicator() {
    Color color = AppColors.primary;
    if (isLiveMode) color = AppColors.warning;
    else if (status == JarvisChatStatus.thinking) color = AppColors.secondary;
    else if (status == JarvisChatStatus.executing) color = Colors.greenAccent;

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 800.ms)
     .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.5));
  }

  Widget _buildMinimalStatusText(BuildContext context) {
    String text = isLiveMode ? 'LIVE SESSION' : 'SECURE CONNECTION';
    if (status == JarvisChatStatus.thinking) text = 'PROCESSING DIRECTIVE...';
    else if (status == JarvisChatStatus.executing) text = 'EXECUTING TASK...';
    else if (status == JarvisChatStatus.recording) text = 'AWAITING INPUT...';
    
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppColors.onSurface.withOpacity(0.5),
        fontSize: context.adaptiveTextSize(9),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ).animate(target: status == JarvisChatStatus.idle ? 0 : 1)
     .fadeIn(duration: 400.ms);
  }

  Widget _buildMinimalActionIcons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleActionButton(
            icon: Icons.psychology_rounded,
            onPressed: onToggleDeepThink,
            isActive: isDeepThinkEnabled,
            activeColor: AppColors.secondary, // Cyan/Electric Blue
          ),
          SizedBox(width: context.adaptiveSpacing(8)),
          _CircleActionButton(
            icon: isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            onPressed: onToggleVoice,
            isActive: isVoiceEnabled,
            activeColor: AppColors.primary,
          ),
          SizedBox(width: context.adaptiveSpacing(8)),
          _CircleActionButton(
            icon: isLiveMode ? Icons.mic_rounded : Icons.mic_none_rounded,
            onPressed: onToggleLive,
            isActive: isLiveMode,
            activeColor: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;

  const _CircleActionButton({
    required this.icon,
    required this.onPressed,
    required this.isActive,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(context.adaptiveSpacing(8)),
        decoration: BoxDecoration(
          color: isActive 
              ? (activeColor ?? AppColors.primary).withOpacity(0.15) 
              : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive 
                ? (activeColor ?? AppColors.primary).withOpacity(0.3) 
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? (activeColor ?? Colors.white) : Colors.white.withOpacity(0.4),
          size: context.adaptiveIconSize(16),
        ),
      ),
    );
  }
}
