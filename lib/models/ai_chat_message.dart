/// AI 交互模式
enum AiMode { chat, agent, plan }

/// AI 聊天消息角色
enum AiMessageRole { user, assistant, system, tool }

/// AI 消息类型
enum AiMessageType { chat, commandSuggestion, errorDiagnosis, explanation }

/// AI 聊天消息模型
class AiChatMessage {
  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime timestamp;
  final AiMessageType type;
  final String? suggestedCommand;
  final bool isStreaming;
  final String? error;
  final String? thinking;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.type = AiMessageType.chat,
    this.suggestedCommand,
    this.isStreaming = false,
    this.error,
    this.thinking,
  });

  /// 创建用户消息
  factory AiChatMessage.user(String content,
      {AiMessageType type = AiMessageType.chat}) {
    return AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      type: type,
    );
  }

  /// 创建助手消息（初始为空，等待流式填充）
  factory AiChatMessage.assistant({
    AiMessageType type = AiMessageType.chat,
    bool isStreaming = true,
  }) {
    return AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      type: type,
      isStreaming: isStreaming,
    );
  }

  /// 创建系统消息
  factory AiChatMessage.system(String content) {
    return AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.system,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// 转换为 OpenAI API 格式
  Map<String, dynamic> toApiMessage() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  AiChatMessage copyWith({
    String? content,
    bool? isStreaming,
    String? suggestedCommand,
    String? error,
    String? thinking,
  }) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      type: type,
      suggestedCommand: suggestedCommand ?? this.suggestedCommand,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
      thinking: thinking ?? this.thinking,
    );
  }

  /// 持久化
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'suggestedCommand': suggestedCommand,
        if (thinking != null) 'thinking': thinking,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => AiChatMessage(
        id: json['id'] as String,
        role: AiMessageRole.values.byName(json['role'] as String),
        content: json['content'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: AiMessageType.values.byName(json['type'] as String? ?? 'chat'),
        suggestedCommand: json['suggestedCommand'] as String?,
        thinking: json['thinking'] as String?,
      );
}
