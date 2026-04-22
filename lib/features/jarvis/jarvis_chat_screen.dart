import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/responsive_utils.dart';
import 'jarvis_models.dart';
import 'widgets/jarvis_header.dart';
import 'widgets/jarvis_message_bubble.dart';
import 'widgets/jarvis_input_bar.dart';
import 'widgets/jarvis_sphere_core.dart';


class JarvisChatScreen extends ConsumerStatefulWidget {
  const JarvisChatScreen({super.key});

  @override
  ConsumerState<JarvisChatScreen> createState() => _JarvisChatScreenState();
}

class _JarvisChatScreenState extends ConsumerState<JarvisChatScreen> {
  // State
  final List<JarvisChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  JarvisChatStatus _status = JarvisChatStatus.idle;
  
  // Voice Integration
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isVoiceEnabled = true;
  bool _isLiveMode = false;
  bool _isDeepThinkEnabled = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String? _imageBase64;
  String? _selectedVoiceName;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initVoiceSystem();
    _addInitialMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initVoiceSystem() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedVoiceName = prefs.getString('jarvis_voice_name');
    
    // Set JARVIS-optimized defaults for a natural human cadence
    await _tts.setPitch(0.95); // Higher pitch for a more natural human male voice
    await _tts.setSpeechRate(0.55); // Slightly faster conversational pace
    await _tts.setVolume(1.0);

    if (_selectedVoiceName != null) {
      final savedLocale = prefs.getString('jarvis_voice_locale') ?? "en-GB";
      await _tts.setVoice({"name": _selectedVoiceName!, "locale": savedLocale});
    } else {
      try {
        final List<dynamic> voices = await _tts.getVoices;
        final jarvisLikeVoice = voices.firstWhere(
          (v) => v["locale"].toString().contains("en-GB") && 
                 (v["name"].toString().toLowerCase().contains("male") || 
                  v["name"].toString().toLowerCase().contains("guy")),
          orElse: () => voices.firstWhere(
            (v) => v["locale"].toString().contains("en-GB"),
            orElse: () => voices.firstWhere(
              (v) => v["name"].toString().toLowerCase().contains("male"),
              orElse: () => null,
            ),
          ),
        );

        if (jarvisLikeVoice != null) {
          _selectedVoiceName = jarvisLikeVoice["name"];
          await _tts.setVoice({"name": _selectedVoiceName!, "locale": jarvisLikeVoice["locale"]});
        } else {
          await _tts.setLanguage("en-GB");
        }
      } catch (e) {
        await _tts.setLanguage("en-GB");
      }
    }

    _tts.setCompletionHandler(() {
      if (_isLiveMode && _status == JarvisChatStatus.idle && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isListening) _toggleListening();
        });
      }
    });
  }

  void _addInitialMessage() {
    setState(() {
      _messages.add(JarvisChatMessage.fromAssistant(
        "I'm online and ready to help, Sir. What's on your mind today?",
        suggestions: ['Strategy Session', 'Profile Analysis', 'Application Status'],
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
    });
  }

  Future<void> _sendMessage(String text, {bool fromVoice = false}) async {
    if (text.trim().isEmpty && _selectedImage == null) return;
    await _tts.stop();

    final capturedImageBase64 = _imageBase64;
    final userMsg = JarvisChatMessage.fromUser(text);
    
    _controller.clear();
    _clearImage();

    setState(() {
      _messages.add(userMsg);
      _status = JarvisChatStatus.thinking;
    });
    _scrollToBottom();

    try {
      final trimmedHistory = _messages.length > 10
          ? _messages.sublist(_messages.length - 10, _messages.length - 1)
          : _messages.sublist(0, _messages.length - 1);

      // Create a skeleton assistant message with a loading indicator
      final assistantMsg = JarvisChatMessage.fromAssistant("...", suggestions: []);
      setState(() {
        _messages.add(assistantMsg);
        _status = JarvisChatStatus.typing;
      });

      String fullContent = "";
      bool handshakeReceived = false;
      final stream = apiClient.postStream(
        '/api/jarvis/chat/stream',
        data: {
          'message': text,
          'history': trimmedHistory.map((m) => m.toJson()).toList(),
          'deep_think': _isDeepThinkEnabled,
          'image_data': capturedImageBase64,
        },
      );

      await for (final token in stream) {
        // Skip the initial "..." handshake token from the backend
        if (!handshakeReceived && token.trim() == '...') {
          handshakeReceived = true;
          continue;
        }
        handshakeReceived = true;
        
        fullContent += token;
        
        // Detect Action Tags for UI status updates
        if (token.contains('[ACTION: EXECUTING]')) {
          setState(() => _status = JarvisChatStatus.executing);
        }

        // Update message content in real-time
        setState(() {
          final cleaned = _cleanStreamContent(fullContent);
          if (cleaned.isNotEmpty && cleaned != '...') {
            assistantMsg.content = cleaned;
          }
        });
        _scrollToBottom();
      }

      // Once stream finishes, extract suggestions from the full text
      final processed = _finalizeStreamedResponse(fullContent);
      setState(() {
        assistantMsg.content = processed.reply;
        assistantMsg.suggestions = processed.suggestions;
        // Reply with voice ONLY if the user spoke or is in Live Mode
        assistantMsg.hasVoice = _isVoiceEnabled && (fromVoice || _isLiveMode);
        _status = assistantMsg.hasVoice ? JarvisChatStatus.speaking : JarvisChatStatus.idle;
      });

      if (assistantMsg.hasVoice) {
        _speak(assistantMsg.content);
      }
    } catch (e) {
      debugPrint("Streaming error: $e");
      setState(() {
        _messages.add(JarvisChatMessage.fromAssistant(
          'I apologize, but I am currently experiencing a connection delay. Please try again in a moment.',
        ));
        _status = JarvisChatStatus.error;
      });
    } finally {
      if (mounted && _status == JarvisChatStatus.thinking) {
        setState(() => _status = JarvisChatStatus.idle);
      }
      _scrollToBottom();
    }
  }

  String _cleanStreamContent(String raw) {
    if (raw.trim().isEmpty || raw.trim() == '...') return '...';
    
    // Strip any leading "..." handshake artifacts from accumulated content
    String stripped = raw;
    if (stripped.startsWith('...')) {
      stripped = stripped.substring(3).trimLeft();
    }
    
    // Strip the engine-pivot apology prefix if present
    const apologyPrefix = 'I apologize, Sir. My primary neural link is currently at capacity. Pivoting to secondary processors now...';
    if (stripped.startsWith(apologyPrefix)) {
      stripped = stripped.substring(apologyPrefix.length).trimLeft();
    }
    
    // Remove suggestion markers and action tags during streaming for cleaner look
    final lines = stripped.split('\n');
    final cleanLines = lines.where((l) {
      final t = l.trim();
      return !t.startsWith('>>') && !t.startsWith('[ACTION:');
    }).toList();
    
    final cleaned = cleanLines.join('\n').trim();
    return cleaned.isEmpty ? '...' : cleaned;
  }

  ({String reply, List<String> suggestions}) _finalizeStreamedResponse(String raw) {
    // Safety: strip any leading "..." handshake artifact
    String cleaned = raw;
    if (cleaned.startsWith('...')) {
      cleaned = cleaned.substring(3).trimLeft();
    }
    // Strip engine-pivot apology prefix
    const apologyPrefix = 'I apologize, Sir. My primary neural link is currently at capacity. Pivoting to secondary processors now...';
    if (cleaned.startsWith(apologyPrefix)) {
      cleaned = cleaned.substring(apologyPrefix.length).trimLeft();
    }
    
    if (cleaned.trim().isEmpty) {
      return (reply: "Directives processed, Sir.", suggestions: ["Next Steps", "Status Check"]);
    }

    final lines = cleaned.split("\n");
    final replyLines = <String>[];
    final suggestions = <String>[];
    
    for (var line in lines) {
      final stripped = line.trim();
      if (stripped.startsWith(">>")) {
        final suggestion = stripped.replaceFirst(">>", "").trim();
        if (suggestion.isNotEmpty) suggestions.add(suggestion);
      } else {
        // Remove action tags from final reply
        final cleanLine = line.replaceAll(RegExp(r'\[ACTION:.*?\]'), '').trim();
        if (cleanLine.isNotEmpty) replyLines.add(cleanLine);
      }
    }
    
    final reply = replyLines.join("\n").trim();
    return (
      reply: reply.isEmpty ? "Neural links synchronized, Sir." : reply, 
      suggestions: suggestions.isEmpty ? ["Strategic Review", "Neural Calibration"] : suggestions
    );
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    setState(() => _status = JarvisChatStatus.speaking);
    
    if (_selectedVoiceName != null) {
      await _tts.setPitch(0.95);
      await _tts.setSpeechRate(0.55);
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString('jarvis_voice_locale') ?? "en-GB";
      await _tts.setVoice({"name": _selectedVoiceName!, "locale": savedLocale});
    } else {
      await _tts.setLanguage("en-GB");
    }
    
    await Future.delayed(const Duration(milliseconds: 50));
    await _tts.speak(text);
    
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _status = JarvisChatStatus.idle);
        // Automatically resume listening if we're in Live Mode
        if (_isLiveMode) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted && _isLiveMode && !_isListening) {
              _toggleListening();
            }
          });
        }
      }
    });
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      await _tts.stop();
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListening = false;
              if (_status == JarvisChatStatus.recording) _status = JarvisChatStatus.idle;
            });
          }
        },
        onError: (val) => setState(() {
          _isListening = false;
          _status = JarvisChatStatus.idle;
        }),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _status = JarvisChatStatus.recording;
        });
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
            if (val.finalResult) {
              _sendMessage(val.recognizedWords, fromVoice: true);
            }
          }),
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _status = JarvisChatStatus.idle;
      });
      _speech.stop();
    }
  }

  void _showVoicePicker() async {
    try {
      final List<dynamic> voices = await _tts.getVoices;
      final englishVoices = voices.where((v) => 
        v["locale"].toString().toLowerCase().contains("en")
      ).toList();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Vocal Calibration",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Select a human-like voice that suits your preference.",
                style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: englishVoices.length,
                  itemBuilder: (context, index) {
                    final voice = englishVoices[index];
                    final name = voice["name"].toString();
                    final isSelected = name == _selectedVoiceName;
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: TextStyle(color: isSelected ? AppColors.primary : Colors.white70, fontSize: 14)),
                      subtitle: Text(voice["locale"].toString(), style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                      onTap: () async {
                        setState(() => _selectedVoiceName = name);
                        await _tts.setVoice({"name": name, "locale": voice["locale"]});
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('jarvis_voice_name', name);
                        await prefs.setString('jarvis_voice_locale', voice["locale"].toString());
                        _speak("Vocal calibration complete, Sir. How does this sound?");
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("Could not load voices: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: JarvisHeader(
        status: _status,
        onBack: () => Navigator.pop(context),
        onTune: _showVoicePicker,
        onToggleVoice: () {
          setState(() {
            _isVoiceEnabled = !_isVoiceEnabled;
            if (!_isVoiceEnabled) _tts.stop();
          });
        },
        onToggleLive: () {
          setState(() {
            _isLiveMode = !_isLiveMode;
            if (_isLiveMode) {
              _isVoiceEnabled = true;
              _toggleListening();
            } else {
              _speech.stop();
            }
          });
        },
        onToggleDeepThink: () => setState(() => _isDeepThinkEnabled = !_isDeepThinkEnabled),
        isVoiceEnabled: _isVoiceEnabled,
        isLiveMode: _isLiveMode,
        isDeepThinkEnabled: _isDeepThinkEnabled,
      ),
      body: Stack(
        children: [
          // Background Centerpiece
          if (_isLiveMode || context.isDesktop)
            Positioned(
              top: context.screenHeight * 0.1,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: _isLiveMode ? 0.7 : (_status == JarvisChatStatus.idle ? 0.1 : 0.5),
                  child: JarvisSphereCore(
                    status: _status,
                    size: context.isMobile 
                        ? (_isLiveMode ? 380 : (_status == JarvisChatStatus.idle ? 250 : 400))
                        : (_isLiveMode ? 500 : (_status == JarvisChatStatus.idle ? 350 : 600)),
                  ),
                ).animate(target: _status == JarvisChatStatus.idle ? 0 : 1)
                 .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1500.ms, curve: Curves.easeOutCubic),
              ),
            ),
          
          // Chat Layer
          Positioned.fill(
            child: Column(
              children: [
                if (!_isLiveMode) ...[
                  Expanded(
                    child: CenteredContent(
                      maxWidth: 900,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(20, 12, 20, context.adaptiveSpacing(20)),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return JarvisMessageBubble(
                            message: _messages[index],
                            onSuggestionTap: (s) => _sendMessage(s),
                            animate: index == _messages.length - 1,
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  CenteredContent(
                    maxWidth: 1000,
                    child: JarvisInputBar(
                      controller: _controller,
                      onSend: () => _sendMessage(_controller.text),
                      onMicTap: _toggleListening,
                      isListening: _isListening,
                      onChanged: (val) => setState(() {}),
                      onPickImage: _pickImage,
                      onClearImage: _clearImage,
                      selectedImagePath: _selectedImage?.path,
                    ),
                  ),
                ] else
                   const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
