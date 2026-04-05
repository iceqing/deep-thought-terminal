import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import '../models/ai_chat_message.dart';

/// AI 服务层
/// 支持 OpenAI 兼容 API 和 Anthropic 格式 API，支持工具调用（Agent 模式）
class AiService {
  AiService._();

  /// 判断 baseUrl 是否为 Anthropic 格式
  static bool _isAnthropicFormat(String baseUrl) {
    return baseUrl.contains('/anthropic');
  }

  // ==================== 工具定义（Anthropic 格式）====================

  static const tools = [
    {
      'name': 'bash',
      'description':
          'Execute a shell command in the terminal and return the output. '
              'Use this for any command: file operations, system info, git, npm, docker, etc.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': 'The shell command to execute. Include pipes, redirects as needed.'
          },
        },
        'required': ['command']
      },
    },
    {
      'name': 'read_file',
      'description':
          'Read the contents of a file. Use this to inspect files before editing or to understand code.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Absolute or relative file path'
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of lines to read (optional). Use when file is large.'
          },
        },
        'required': ['path']
      },
    },
    {
      'name': 'write_file',
      'description':
          'Write content to a file. Creates the file if it does not exist, overwrites if it does.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'File path'},
          'content': {'type': 'string', 'description': 'Full file content to write'},
        },
        'required': ['path', 'content']
      },
    },
    {
      'name': 'edit_file',
      'description':
          'Replace exact text in a file. Use this for small edits to existing files. '
              'The old_text must match exactly (including whitespace).',
      'input_schema': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'File path'},
          'old_text': {'type': 'string', 'description': 'Exact text to find and replace'},
          'new_text': {'type': 'string', 'description': 'Replacement text'},
        },
        'required': ['path', 'old_text', 'new_text']
      },
    },
  ];

  // ==================== Agent Turn ====================

  /// Agent 模式的单轮交互
  /// 调用 LLM，返回文本/思考过程/工具调用
  /// 由调用方负责执行工具并循环
  static Future<AgentTurnResult> agentTurn({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async {
    final isAnthropic = _isAnthropicFormat(config.baseUrl);

    if (isAnthropic) {
      return _anthropicAgentTurn(
        config: config,
        messages: messages,
        systemPromptOverride: systemPromptOverride,
      );
    }

    return _openaiAgentTurn(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
    );
  }

  /// 执行工具调用（支持同步和异步执行器）
  static Future<String> executeTool(
    String name,
    Map<String, dynamic> input,
    Future<String> Function(String name, Map<String, dynamic> input) executor,
  ) async {
    return executor(name, input);
  }

  // ==================== Legacy API（保留给 Chat/CommandSuggestion 模式）====================

  /// 发送聊天补全请求（非流式）
  static Future<String> chatCompletion({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async {
    final isAnthropic = _isAnthropicFormat(config.baseUrl);

    if (isAnthropic) {
      return _anthropicCompletion(
        config: config,
        messages: messages,
        systemPromptOverride: systemPromptOverride,
      );
    }

    return _openaiCompletion(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
    );
  }

  /// 发送流式聊天补全请求
  static Stream<AiStreamEvent> chatCompletionStream({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) {
    final isAnthropic = _isAnthropicFormat(config.baseUrl);

    if (isAnthropic) {
      return _anthropicStream(
        config: config,
        messages: messages,
        systemPromptOverride: systemPromptOverride,
      );
    }

    return _openaiStream(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
    );
  }

  /// 快速生成 shell 命令（单轮）
  static Future<String> generateCommand({
    required AiConfig config,
    required String naturalLanguage,
    String? cwd,
    String? shellType,
  }) async {
    final systemPrompt = config.resolveSystemPrompt(
      shellType: shellType,
      cwd: cwd,
    );

    final messages = [
      AiChatMessage.user(
        'Generate a shell command for: $naturalLanguage\n'
        'Output ONLY the command, no explanation, no markdown, no code fences.',
      ),
    ];

    return chatCompletion(
      config: config,
      messages: messages,
      systemPromptOverride: systemPrompt,
    );
  }

  /// 解释命令
  static Future<String> explainCommand({
    required AiConfig config,
    required String command,
  }) async {
    final messages = [
      AiChatMessage.user(
        'Explain what this shell command does in Chinese:\n$command',
      ),
    ];

    return chatCompletion(
      config: config,
      messages: messages,
    );
  }

  /// 诊断命令错误
  static Future<String> diagnoseError({
    required AiConfig config,
    required String command,
    required String errorOutput,
    required int exitCode,
    String? cwd,
    String? shellType,
  }) async {
    final systemPrompt = config.resolveSystemPrompt(
      shellType: shellType,
      cwd: cwd,
      lastCommand: command,
    );

    final messages = [
      AiChatMessage.user(
        'The following command failed with exit code $exitCode:\n'
        'Command: $command\n'
        'Error output:\n$errorOutput\n\n'
        'Diagnose the error and suggest a fix. Reply in Chinese.',
      ),
    ];

    return chatCompletion(
      config: config,
      messages: messages,
      systemPromptOverride: systemPrompt,
    );
  }

  /// 验证 API 连接
  static Future<String?> validateConnection(AiConfig config) async {
    try {
      final result = await chatCompletion(
        config: config,
        messages: [AiChatMessage.user('Reply with just "OK"')],
      );
      if (result.isEmpty) {
        return 'API returned empty response';
      }
      return null;
    } on AiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  // ==================== Anthropic Agent Turn ====================

  static Future<AgentTurnResult> _anthropicAgentTurn({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async {
    final url = _buildAnthropicUrl(config.baseUrl);
    final headers = _buildAnthropicHeaders(config.apiKey);
    final body = _buildAnthropicBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      tools: tools,
    );

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw AiException('API error ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List? ?? [];
      final stopReason = json['stop_reason'] as String? ?? '';

      String text = '';
      String thinking = '';
      final toolCalls = <AiToolCall>[];

      for (final block in content) {
        final map = block as Map<String, dynamic>;
        final type = map['type'] as String?;
        if (type == 'text') {
          text += map['text'] as String? ?? '';
        } else if (type == 'thinking') {
          thinking += map['thinking'] as String? ?? '';
        } else if (type == 'tool_use') {
          toolCalls.add(AiToolCall(
            id: map['id'] as String? ?? '',
            name: map['name'] as String? ?? '',
            input: Map<String, dynamic>.from(map['input'] as Map? ?? {}),
          ));
        }
      }

      return AgentTurnResult(
        text: text,
        thinking: thinking,
        toolCalls: toolCalls,
        stopReason: stopReason,
      );
    } on TimeoutException {
      throw AiException('Agent turn timed out');
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('Failed to connect: $e');
    }
  }

  // ==================== OpenAI Agent Turn ====================

  static Future<AgentTurnResult> _openaiAgentTurn({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async {
    final url = _buildOpenAiUrl(config.baseUrl);
    final headers = _buildOpenAiHeaders(config.apiKey);
    final body = _buildOpenAiBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      tools: tools,
    );

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw AiException('API error ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List? ?? [];
      if (choices.isEmpty) {
        throw AiException('No response from AI');
      }

      final message = choices.first['message'] as Map<String, dynamic>? ?? {};
      final toolCalls = <AiToolCall>[];

      final rawToolCalls = message['tool_calls'] as List? ?? [];
      for (final tc in rawToolCalls) {
        final fn = tc['function'] as Map<String, dynamic>? ?? {};
        toolCalls.add(AiToolCall(
          id: tc['id'] as String? ?? '',
          name: fn['name'] as String? ?? '',
          input: Map<String, dynamic>.from(
            jsonDecode(fn['arguments'] as String? ?? '{}') as Map? ?? {},
          ),
        ));
      }

      return AgentTurnResult(
        text: message['content'] as String? ?? '',
        thinking: '',
        toolCalls: toolCalls,
        stopReason: toolCalls.isNotEmpty ? 'tool_calls' : 'stop',
      );
    } on TimeoutException {
      throw AiException('Agent turn timed out');
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('Failed to connect: $e');
    }
  }

  // ==================== OpenAI 兼容格式 ====================

  static Future<String> _openaiCompletion({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
    bool stream = false,
  }) async {
    final url = _buildOpenAiUrl(config.baseUrl);
    final headers = _buildOpenAiHeaders(config.apiKey);
    final body = _buildOpenAiBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      stream: stream,
    );

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw AiException('API error ${response.statusCode}: ${response.body}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw AiException('No response from AI');
      }
      return choices.first['message']['content'] as String? ?? '';
    } on TimeoutException {
      throw AiException('Request timed out');
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('Failed to connect: $e');
    }
  }

  static Stream<AiStreamEvent> _openaiStream({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async* {
    final url = _buildOpenAiUrl(config.baseUrl);
    final headers = _buildOpenAiHeaders(config.apiKey);
    final body = _buildOpenAiBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      stream: true,
    );

    final request = http.Request('POST', url);
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    try {
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw AiException(
            'API error ${streamedResponse.statusCode}: $errorBody');
      }

      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices.first['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield AiStreamEvent(content);
          }
        } catch (_) {
          // 跳过解析失败的行
        }
      }
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Failed to connect: $e');
    }
  }

  // ==================== Anthropic 格式 ====================

  static Future<String> _anthropicCompletion({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
    bool stream = false,
  }) async {
    final url = _buildAnthropicUrl(config.baseUrl);
    final headers = _buildAnthropicHeaders(config.apiKey);
    final body = _buildAnthropicBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
    );

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw AiException('API error ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null || content.isEmpty) {
        throw AiException('No response from AI');
      }
      // Find the first text block, skipping thinking blocks
      for (final block in content) {
        final map = block as Map<String, dynamic>;
        if (map['type'] == 'text') {
          return map['text'] as String? ?? '';
        }
      }
      return '';
    } on TimeoutException {
      throw AiException('Request timed out');
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('Failed to connect: $e');
    }
  }

  /// Anthropic SSE 流式解析
  static Stream<AiStreamEvent> _anthropicStream({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
  }) async* {
    final url = _buildAnthropicUrl(config.baseUrl);
    final headers = _buildAnthropicHeaders(config.apiKey);
    final body = _buildAnthropicBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      stream: true,
    );

    final request = http.Request('POST', url);
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    try {
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw AiException(
            'API error ${streamedResponse.statusCode}: $errorBody');
      }

      String currentEvent = '';
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.startsWith('event: ')) {
            currentEvent = trimmed.substring(7).trim();
          } else if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6).trim();
            if (data == '[DONE]') break;

            if (currentEvent == 'content_block_delta') {
              try {
                final json = jsonDecode(data) as Map<String, dynamic>;
                final delta = json['delta'] as Map<String, dynamic>?;
                if (delta?['type'] == 'text_delta') {
                  final text = delta?['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    yield AiStreamEvent(text);
                  }
                } else if (delta?['type'] == 'thinking_delta') {
                  final thinking = delta?['thinking'] as String?;
                  if (thinking != null && thinking.isNotEmpty) {
                    yield AiStreamEvent(thinking, isThinking: true);
                  }
                }
              } catch (_) {
                // 跳过解析失败的行
              }
            }
          }
        }
      }
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Failed to connect: $e');
    }
  }

  // ==================== Internal helpers ====================

  static Uri _buildOpenAiUrl(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.contains('/chat/completions')) {
      url = '$url/chat/completions';
    }
    return Uri.parse(url);
  }

  static Map<String, String> _buildOpenAiHeaders(String apiKey) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  static Map<String, dynamic> _buildOpenAiBody({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
  }) {
    final apiMessages = <Map<String, dynamic>>[];

    final system = systemPromptOverride ?? config.resolveSystemPrompt();
    if (system.isNotEmpty) {
      apiMessages.add({'role': 'system', 'content': system});
    }

    for (final msg in messages) {
      if (msg.role == AiMessageRole.system) continue;
      apiMessages.add(msg.toApiMessage());
    }

    final body = <String, dynamic>{
      'model': config.model,
      'messages': apiMessages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }
    return body;
  }

  static Uri _buildAnthropicUrl(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.contains('/messages')) {
      url = '$url/messages';
    }
    return Uri.parse(url);
  }

  static Map<String, String> _buildAnthropicHeaders(String apiKey) => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };

  static Map<String, dynamic> _buildAnthropicBody({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
    bool stream = false,
    List<Map<String, dynamic>>? tools,
  }) {
    final system = systemPromptOverride ?? config.resolveSystemPrompt();

    final apiMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == AiMessageRole.system) continue;
      apiMessages.add(msg.toApiMessage());
    }

    final body = <String, dynamic>{
      'model': config.model,
      'messages': apiMessages,
      if (system.isNotEmpty) 'system': system,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }
    return body;
  }
}

// ==================== Tool Executor ====================

/// 工具执行器类型：给定工具名和参数，返回执行结果字符串
typedef ToolExecutor = String Function(
    String name, Map<String, dynamic> input);

/// 默认工具执行器（文件系统操作 + 模拟 bash）
/// 实际 bash 命令执行由调用方通过 TerminalSession 提供
Future<String> defaultToolExecutor(
    String name, Map<String, dynamic> input) async {
  switch (name) {
    case 'read_file':
      final path = input['path'] as String? ?? '';
      final limit = input['limit'] as int?;
      try {
        final file = File(path);
        var content = await file.readAsString();
        final lines = content.split('\n');
        if (limit != null && limit < lines.length) {
          content =
              lines.take(limit).join('\n') + '\n... (${lines.length - limit} more lines)';
        }
        return content;
      } catch (e) {
        return 'Error reading $path: $e';
      }

    case 'write_file':
      final path = input['path'] as String? ?? '';
      final content = input['content'] as String? ?? '';
      try {
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString(content);
        return 'Wrote ${content.length} bytes to $path';
      } catch (e) {
        return 'Error writing $path: $e';
      }

    case 'edit_file':
      final path = input['path'] as String? ?? '';
      final oldText = input['old_text'] as String? ?? '';
      final newText = input['new_text'] as String? ?? '';
      try {
        final file = File(path);
        final content = await file.readAsString();
        if (!content.contains(oldText)) {
          return 'Error: old_text not found in $path';
        }
        final newContent = content.replaceFirst(oldText, newText);
        await file.writeAsString(newContent);
        return 'Edited $path';
      } catch (e) {
        return 'Error editing $path: $e';
      }

    default:
      return 'Unknown tool: $name';
  }
}

// ==================== Response Types ====================

/// Agent 单轮结果
class AgentTurnResult {
  final String text;
  final String thinking;
  final List<AiToolCall> toolCalls;
  final String stopReason;

  const AgentTurnResult({
    required this.text,
    required this.thinking,
    required this.toolCalls,
    required this.stopReason,
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get isComplete => stopReason != 'tool_use' && toolCalls.isEmpty;
}

/// AI 流式事件
class AiStreamEvent {
  final String text;
  final bool isThinking;
  const AiStreamEvent(this.text, {this.isThinking = false});
}

/// AI 服务异常
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => 'AiException: $message';
}
