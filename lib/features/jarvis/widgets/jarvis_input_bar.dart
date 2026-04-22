import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';

class JarvisInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final bool isListening;
  final ValueChanged<String>? onChanged;
  final VoidCallback onPickImage;
  final String? selectedImagePath;
  final VoidCallback onClearImage;

  const JarvisInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onMicTap,
    required this.onPickImage,
    required this.onClearImage,
    this.selectedImagePath,
    this.isListening = false,
    this.onChanged,
  });

  @override
  State<JarvisInputBar> createState() => _JarvisInputBarState();
}

class _JarvisInputBarState extends State<JarvisInputBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, context.isMobile ? 30 : 20),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.98),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.selectedImagePath != null) _buildImagePreview(),
            Row(
              children: [
                _buildAttachmentButton(),
                SizedBox(width: context.adaptiveSpacing(10)),
                Expanded(
                  child: _buildRefinedTextField(),
                ),
                SizedBox(width: context.adaptiveSpacing(10)),
                _buildAnimatedMicButton(),
                SizedBox(width: context.adaptiveSpacing(10)),
                _buildRefinedSendButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.selectedImagePath!), 
                height: 64, 
                width: 64, 
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: widget.onClearImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
          Positioned(
            left: 80,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                'Ready for analysis, Sir.',
                style: GoogleFonts.inter(
                  color: Colors.white60, 
                  fontSize: context.adaptiveTextSize(12), 
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildAttachmentButton() {
    return GestureDetector(
      onTap: widget.onPickImage,
      child: Container(
        padding: EdgeInsets.all(context.adaptiveSpacing(12)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_photo_alternate_outlined, 
                   color: Colors.white.withOpacity(0.7), 
                   size: context.adaptiveIconSize(20)),
      ),
    );
  }

  Widget _buildRefinedTextField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _isFocused ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isFocused ? AppColors.primary.withOpacity(0.4) : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: _isFocused ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ] : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onSubmitted: (_) => widget.onSend(),
        style: GoogleFonts.inter(
          color: Colors.white, 
          fontSize: context.adaptiveTextSize(15), 
          letterSpacing: 0.3,
        ),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Awaiting directive...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: context.adaptiveTextSize(14),
            letterSpacing: 0.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAnimatedMicButton() {
    return GestureDetector(
      onTap: widget.onMicTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(context.adaptiveSpacing(14)),
        decoration: BoxDecoration(
          color: widget.isListening ? AppColors.warning : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          boxShadow: widget.isListening ? [
            BoxShadow(color: AppColors.warning.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
          ] : [],
        ),
        child: Icon(
          widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: widget.isListening ? Colors.black : Colors.white60,
          size: context.adaptiveIconSize(20),
        ),
      ),
    );
  }

  Widget _buildRefinedSendButton() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: widget.onSend,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(context.adaptiveSpacing(14)),
        decoration: BoxDecoration(
          color: hasText ? AppColors.primary : Colors.white.withOpacity(0.03),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: hasText ? Colors.white : Colors.white24,
          size: context.adaptiveIconSize(20),
        ),
      ),
    ).animate(target: hasText ? 1 : 0).scale(end: const Offset(1.05, 1.05), duration: 200.ms);
  }
}
