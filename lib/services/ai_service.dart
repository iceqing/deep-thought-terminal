import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import '../models/ai_chat_message.dart';

/// AI 服务层
/// 支持 OpenAI 兼容 API 和 Anthropic 格式 API
class AiService {
  AiService._();

  /// 判断 baseUrl 是否为 Anthropic 格式
  /// Anthropic 格式: 包含 /anthropic 路径
  static bool _isAnthropicFormat(String baseUrl) {
    return baseUrl.contains('/anthropic');
  }

  // ==================== 公开 API ====================

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
        stream: false,
      );
    }

    return _openaiCompletion(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
      stream: false,
    );
  }

  /// 发送流式聊天补全请求
  /// 返回一个 Stream<AiStreamEvent>，每个事件是一段文本增量（可区分 thinking/text）
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

  /// 快速生成 shell 命令（单轮，返回纯命令文本）
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

    // Debug
    final isAnthropic = _isAnthropicFormat(config.baseUrl);
    final actualUrl = isAnthropic
        ? _buildAnthropicUrl(config.baseUrl)
        : _buildOpenAiUrl(config.baseUrl);
    // ignore: avoid_print
    print(
        '[AiService] generateCommand URL: $actualUrl, isAnthropic: $isAnthropic, model: ${config.model}');
    // ignore: avoid_print
    print(
        '[AiService] systemPrompt: ${systemPrompt.substring(0, systemPrompt.length > 100 ? 100 : systemPrompt.length)}...');
    // ignore: avoid_print
    print(
        '[AiService] messages: ${messages.map((m) => '${m.role.name}: ${m.content.substring(0, m.content.length > 80 ? 80 : m.content.length)}').toList()}');

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
      return null; // null 表示成功
    } on AiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  // ==================== OpenAI 兼容格式 ====================

  static Future<String> _openaiCompletion({
    required AiConfig config,
    required List<AiChatMessage> messages,
    String? systemPromptOverride,
    required bool stream,
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
        // ignore: avoid_print
        print(
            '[AiService] Error response: ${response.statusCode} ${response.body}');
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
    required bool stream,
  }) async {
    final url = _buildAnthropicUrl(config.baseUrl);
    final headers = _buildAnthropicHeaders(config.apiKey);
    final body = _buildAnthropicBody(
      config: config,
      messages: messages,
      systemPromptOverride: systemPromptOverride,
    );

    // ignore: avoid_print
    print('[AiService] Anthropic request URL: $url');
    // ignore: avoid_print
    print(
        '[AiService] Anthropic request headers: ${headers.map((k, v) => MapEntry(k, k == 'x-api-key' ? '${v.substring(0, v.length > 8 ? 8 : v.length)}...' : v))}');
    // ignore: avoid_print
    print('[AiService] Anthropic request body: ${jsonEncode(body)}');

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      // ignore: avoid_print
      print('[AiService] Anthropic response status: ${response.statusCode}');
      // ignore: avoid_print
      print(
          '[AiService] Anthropic response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode != 200) {
        throw AiException('API error ${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null || content.isEmpty) {
        // ignore: avoid_print
        print(
            '[AiService] Anthropic response JSON keys: ${json.keys.toList()}, full: ${jsonEncode(json).substring(0, 300)}');
        throw AiException('No response from AI');
      }
      // Find the first text block, skipping thinking blocks
      for (final block in content) {
        final map = block as Map<String, dynamic>;
        if (map['type'] == 'text') {
          return map['text'] as String? ?? '';
        }
      }
      // Fallback: try the first block's text field
      final firstBlock = content.first as Map<String, dynamic>;
      return firstBlock['text'] as String? ?? '';
    } on TimeoutException {
      // ignore: avoid_print
      print('[AiService] Anthropic request timed out');
      throw AiException('Request timed out');
    } catch (e) {
      // ignore: avoid_print
      print('[AiService] Anthropic error: $e');
      if (e is AiException) rethrow;
      throw AiException('Failed to connect: $e');
    }
  }

  /// Anthropic SSE 流式解析
  /// 事件格式: event: content_block_delta\\ndata: {...}
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
          if (trimmed.isEmpty) {
            // 空行表示事件结束，解析 accumulated data
            continue;
          }
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

  // OpenAI 格式
  static Uri _buildOpenAiUrl(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    // 避免重复追加路径
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
    required bool stream,
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

    return {
      'model': config.model,
      'messages': apiMessages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };
  }

  // Anthropic 格式
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
  }) {
    final system = systemPromptOverride ?? config.resolveSystemPrompt();

    // Anthropic messages 格式: role + content (content 可以是字符串或对象数组)
    final apiMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == AiMessageRole.system) continue;
      if (msg.role == AiMessageRole.tool) continue; // 暂不支持 tool

      // Anthropic 只支持 user 和 assistant
      if (msg.role == AiMessageRole.user ||
          msg.role == AiMessageRole.assistant) {
        apiMessages.add({
          'role': msg.role.name,
          'content': msg.content,
        });
      }
    }

    return {
      'model': config.model,
      'messages': apiMessages,
      if (system.isNotEmpty) 'system': system,
      'max_tokens': config.maxTokens,
      'stream': stream,
    };
  }
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
