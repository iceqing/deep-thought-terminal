import 'ai_chat_message.dart';

class AiChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<AiChatMessage> messages;

  AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<AiChatMessage>? messages,
  }) : messages = messages ?? [];

  factory AiChatSession.create({String? title}) {
    final now = DateTime.now();
    return AiChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: title ?? 'New Chat',
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List? ?? const [];
    return AiChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? json['createdAt'] as String,
      ),
      messages: rawMessages
          .map((item) => AiChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
