import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../jarvis_models.dart';
import 'jarvis_typing_indicator.dart';

class JarvisMessageBubble extends StatefulWidget {
  final JarvisChatMessage message;
  final Function(String) onSuggestionTap;
  final bool animate;

  const JarvisMessageBubble({
    super.key,
    required this.message,
    required this.onSuggestionTap,
    this.animate = false,
  });

  @override
  State<JarvisMessageBubble> createState() => _JarvisMessageBubbleState();
}

class _JarvisMessageBubbleState extends State<JarvisMessageBubble> {
  String _displayedContent = "";
  String _lastKnownContent = "";
  Timer? _typewriterTimer;
  bool _isTyping = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _displayedContent = widget.message.content;
    _lastKnownContent = widget.message.content;
    // Only start typewriter for non-placeholder content (e.g., the welcome message)
    if (widget.animate && widget.message.role == JarvisChatRole.assistant 
        && _displayedContent.isNotEmpty && _displayedContent != "...") {
      _startTypewriter();
    }
  }

  @override
  void didUpdateWidget(covariant JarvisMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CRITICAL: Compare against our locally tracked content, NOT oldWidget.message.content,
    // because JarvisChatMessage is mutable and both old/new widget share the same object reference.
    final currentContent = widget.message.content;
    
    if (currentContent != _lastKnownContent) {
      final previousContent = _lastKnownContent;
      _lastKnownContent = currentContent;
      
      if (currentContent == "...") {
        // Still in placeholder state
        setState(() => _displayedContent = currentContent);
        return;
      }
      
      // Detect if we're receiving streaming updates (rapid content changes)
      if (previousContent == "..." || _isStreaming) {
        // We're transitioning from placeholder to real content, or continuing streaming
        // Cancel any running typewriter — during streaming, show text directly
        _typewriterTimer?.cancel();
        _isStreaming = true;
        _isTyping = false;
        setState(() => _displayedContent = currentContent);
        return;
      }
      
      // Non-streaming content update (e.g., final content set after stream ends)
      if (currentContent.isNotEmpty) {
        setState(() => _displayedContent = currentContent);
      }
    }
    
    // Detect when suggestions appear (signals streaming is done) — finalize state
    if (widget.message.suggestions != null && 
        widget.message.suggestions!.isNotEmpty &&
        _isStreaming) {
      _isStreaming = false;
      _isTyping = false;
      _lastKnownContent = widget.message.content;
      setState(() => _displayedContent = widget.message.content);
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    setState(() {
      _isTyping = true;
      _displayedContent = "";
    });

    final words = widget.message.content.split(' ');
    int wordIndex = 0;
    
    // Smooth word-by-word pacing
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (wordIndex < words.length) {
        if (mounted) {
          setState(() {
            _displayedContent += (wordIndex == 0 ? "" : " ") + words[wordIndex];
            wordIndex++;
          });
        }
      } else {
        _finishTyping();
      }
    });
  }

  void _finishTyping() {
    _typewriterTimer?.cancel();
    if (mounted) {
      setState(() {
        _isTyping = false;
        _displayedContent = widget.message.content;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJarvis = widget.message.role == JarvisChatRole.assistant;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isJarvis ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isJarvis ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isJarvis) _buildAssistantPresence(),
              const SizedBox(width: 12),
              Flexible(
                child: GestureDetector(
                  onTap: _isTyping ? _finishTyping : null,
                  child: isJarvis 
                    ? (_displayedContent == "..." ? JarvisTypingIndicator() : _buildAssistantBubble(context))
                    : _buildUserBubble(context),
                ),
              ),
              const SizedBox(width: 8),
              if (!isJarvis) _buildUserPresence(),
            ],
          ),
          if (widget.message.suggestions != null && widget.message.suggestions!.isNotEmpty && !_isTyping)
            _buildSuggestions(context),
        ],
      ).animate()
       .fadeIn(duration: 600.ms, delay: 100.ms, curve: Curves.easeOut)
       .slideY(begin: 0.05, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildAssistantPresence() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 4,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3));
  }

  Widget _buildUserPresence() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: Colors.white.withOpacity(0.05),
        child: const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white38),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'JARVIS',
            style: GoogleFonts.inter(
              color: AppColors.primary.withOpacity(0.5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: MarkdownBody(
            data: _displayedContent,
            selectable: !_isTyping,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.95),
                fontSize: 15,
                height: 1.5,
              ),
              strong: GoogleFonts.outfit(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              em: const TextStyle(fontStyle: FontStyle.italic),
              code: GoogleFonts.firaCode(
                backgroundColor: Colors.black26,
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      borderRadius: 24,
      opacity: 0.1,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: MarkdownBody(
          data: widget.message.content,
          styleSheet: MarkdownStyleSheet(
            p: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: widget.message.suggestions!.map((s) => GestureDetector(
          onTap: () => widget.onSuggestionTap(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      color: AppColors.primary.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9))).toList(),
      ),
    );
  }
}
