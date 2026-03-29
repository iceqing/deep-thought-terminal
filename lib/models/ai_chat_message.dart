/// AI 交互模式
enum AiMode { chat, agent, plan }

/// AI 聊天消息角色
enum AiMessageRole { user, assistant, system, tool }

/// AI 消息类型
enum AiMessageType { chat, commandSuggestion, errorDiagnosis, explanation, agent }

/// 单个工具调用
class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  const AiToolCall({
    required this.id,
    required this.name,
    required this.input,
  });
}

/// 单个工具结果
class AiToolResult {
  final String toolCallId;
  final String output;
  const AiToolResult({
    required this.toolCallId,
    required this.output,
  });
}

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
  /// 助手消息中的工具调用列表
  final List<AiToolCall>? toolCalls;
  /// 用户消息中的工具结果列表（Anthropic 格式）
  final List<AiToolResult>? toolResults;

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
    this.toolCalls,
    this.toolResults,
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

  /// 创建包含工具调用的助手消息
  factory AiChatMessage.assistantWithToolCalls(
    List<AiToolCall> toolCalls, {
    AiMessageType type = AiMessageType.agent,
  }) {
    return AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      type: type,
      toolCalls: toolCalls,
      isStreaming: false,
    );
  }

  /// 创建包含工具结果的用户消息（用于 Anthropic API）
  factory AiChatMessage.userWithToolResults(List<AiToolResult> results) {
    return AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.user,
      content: '',
      timestamp: DateTime.now(),
      toolResults: results,
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

  /// 转换为 API 消息格式
  /// Anthropic 格式支持 content blocks（工具调用/工具结果）
  Map<String, dynamic> toApiMessage() {
    if (role == AiMessageRole.assistant && toolCalls != null) {
      // Anthropic assistant 消息 with tool_use content blocks
      final blocks = <Map<String, dynamic>>[];
      if (content.isNotEmpty) {
        blocks.add({'type': 'text', 'text': content});
      }
      for (final tc in toolCalls!) {
        blocks.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.name,
          'input': tc.input,
        });
      }
      return {
        'role': role.name,
        'content': blocks.isEmpty ? null : blocks,
      };
    }
    if (role == AiMessageRole.user && toolResults != null) {
      // Anthropic user 消息 with tool_result content blocks
      final blocks = toolResults!
          .map((tr) => {
                'type': 'tool_result',
                'tool_use_id': tr.toolCallId,
                'content': tr.output,
              })
          .toList();
      return {
        'role': role.name,
        'content': blocks,
      };
    }
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
    List<AiToolCall>? toolCalls,
    List<AiToolResult>? toolResults,
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
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
    );
  }

  /// 持久化（不包含 tool 调用结果，仅保留文本）
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
