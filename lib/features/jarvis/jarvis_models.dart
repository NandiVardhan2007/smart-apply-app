


enum JarvisChatRole { user, assistant, system }

enum JarvisChatStatus { idle, typing, thinking, recording, speaking, executing, error }

class JarvisChatMessage {
  final JarvisChatRole role;
  String content;
  List<String>? suggestions;
  final DateTime timestamp;
  bool hasVoice;

  JarvisChatMessage({
    required this.role,
    required this.content,
    this.suggestions,
    required this.timestamp,
    this.hasVoice = false,
  });

  Map<String, dynamic> toJson() => {
    'role': role == JarvisChatRole.user ? 'user' : 'assistant',
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory JarvisChatMessage.fromAssistant(String content, {List<String>? suggestions, bool hasVoice = false}) {
    return JarvisChatMessage(
      role: JarvisChatRole.assistant,
      content: content,
      suggestions: suggestions,
      timestamp: DateTime.now(),
      hasVoice: hasVoice,
    );
  }

  factory JarvisChatMessage.fromUser(String content) {
    return JarvisChatMessage(
      role: JarvisChatRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }
}
