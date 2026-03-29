import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_config.dart';
import '../models/ai_chat_message.dart';
import '../services/ai_service.dart';

/// AI 状态管理
/// 管理配置、聊天记录、面板状态、流式响应
class AiProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  AiConfig _config = const AiConfig();
  final List<AiChatMessage> _chatHistory = [];
  bool _isPanelOpen = false;
  bool _isStreaming = false;
  String? _lastError;
  StreamSubscription? _streamSubscription;
  int _maxHistoryLength = 100;
  AiMode _currentMode = AiMode.agent;

  // --- Getters ---
  bool get initialized => _initialized;
  AiConfig get config => _config;
  List<AiChatMessage> get chatHistory => List.unmodifiable(_chatHistory);
  bool get isPanelOpen => _isPanelOpen;
  bool get isStreaming => _isStreaming;
  bool get isEnabled => _config.enabled;
  bool get isConfigured => _config.isConfigured;
  String? get lastError => _lastError;
  AiMode get currentMode => _currentMode;

  void setMode(AiMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  /// 初始化 - 从 SharedPreferences 加载配置
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadConfig();
    _loadHistory();
    _initialized = true;
    notifyListeners();
  }

  // ==================== 配置管理 ====================

  void _loadConfig() {
    final jsonStr = _prefs.getString('ai_config');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        _config = AiConfig.fromJson(jsonDecode(jsonStr));
      } catch (_) {
        _config = const AiConfig();
      }
    }
  }

  Future<void> updateConfig(AiConfig config) async {
    _config = config;
    await _prefs.setString('ai_config', jsonEncode(config.toJson()));
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _config = _config.copyWith(enabled: enabled);
    await _prefs.setString('ai_config', jsonEncode(_config.toJson()));
    notifyListeners();
  }

  // ==================== 面板状态 ====================

  void togglePanel() {
    _isPanelOpen = !_isPanelOpen;
    notifyListeners();
  }

  void openPanel() {
    _isPanelOpen = true;
    notifyListeners();
  }

  void closePanel() {
    _isPanelOpen = false;
    notifyListeners();
  }

  // ==================== 聊天操作 ====================

  /// 发送聊天消息（流式响应或 Agent 循环）
  Future<void> sendMessage(
    String userMessage, {
    String? cwd,
    String? lastCommand,
    String? shellType,
    String? lastCommandOutput,
    required String Function(String name, Map<String, dynamic> input) toolExecutor,
  }) async {
    if (!isConfigured) {
      _lastError = 'AI is not configured. Please set API key in settings.';
      notifyListeners();
      return;
    }

    // Agent 模式走循环执行
    if (_currentMode == AiMode.agent) {
      await runAgentLoop(
        userMessage,
        cwd: cwd,
        shellType: shellType,
        toolExecutor: toolExecutor,
      );
      return;
    }

    // 追加用户消息
    final userMsg = AiChatMessage.user(userMessage);
    _chatHistory.add(userMsg);

    // 追加助手消息（初始为空，等待流式填充）
    final assistantMsg = AiChatMessage.assistant();
    _chatHistory.add(assistantMsg);

    _isStreaming = true;
    _lastError = null;
    notifyListeners();

    final basePrompt = _config.resolveSystemPrompt(
      shellType: shellType,
      cwd: cwd,
      lastCommand: lastCommand,
    );
    final systemPrompt = _buildModePrompt(basePrompt);

    try {
      // 构建上下文消息（最近 N 条）
      final contextMessages = _buildContextMessages();

      _streamSubscription = AiService.chatCompletionStream(
        config: _config,
        messages: contextMessages,
        systemPromptOverride: systemPrompt,
      ).listen(
        (event) {
          final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
          if (idx >= 0) {
            if (event.isThinking) {
              _chatHistory[idx] = _chatHistory[idx].copyWith(
                thinking: (_chatHistory[idx].thinking ?? '') + event.text,
              );
            } else {
              _chatHistory[idx] = _chatHistory[idx].copyWith(
                content: _chatHistory[idx].content + event.text,
              );
            }
            notifyListeners();
          }
        },
        onDone: () {
          _finalizeStreaming(assistantMsg.id);
        },
        onError: (error) {
          final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
          if (idx >= 0) {
            _chatHistory[idx] = _chatHistory[idx].copyWith(
              isStreaming: false,
              error: error.toString(),
            );
          }
          _isStreaming = false;
          _lastError = error.toString();
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (e) {
      final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
      if (idx >= 0) {
        _chatHistory[idx] = _chatHistory[idx].copyWith(
          isStreaming: false,
          error: e.toString(),
        );
      }
      _isStreaming = false;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  /// 快速生成命令（同时记录到聊天历史）
  Future<String?> generateCommand(
    String naturalLanguage, {
    String? cwd,
    String? shellType,
  }) async {
    if (!isConfigured) {
      _lastError = 'AI is not configured';
      notifyListeners();
      return null;
    }

    // Record user query in chat history
    _chatHistory.add(AiChatMessage.user(
      naturalLanguage,
      type: AiMessageType.commandSuggestion,
    ));
    notifyListeners();

    try {
      final command = await AiService.generateCommand(
        config: _config,
        naturalLanguage: naturalLanguage,
        cwd: cwd,
        shellType: shellType,
      );
      final cleaned = _cleanCommand(command);

      // Record AI response in chat history
      _chatHistory.add(AiChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: AiMessageRole.assistant,
        content: cleaned,
        timestamp: DateTime.now(),
        type: AiMessageType.commandSuggestion,
        suggestedCommand: cleaned,
      ));
      notifyListeners();
      _saveHistory();

      return cleaned;
    } on AiException catch (e) {
      // ignore: avoid_print
      print('[AiProvider] generateCommand AiException: ${e.message}');
      _lastError = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[AiProvider] generateCommand unexpected error: $e');
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 诊断命令错误
  Future<void> diagnoseError({
    required String command,
    required String errorOutput,
    required int exitCode,
    String? cwd,
    String? shellType,
  }) async {
    if (!isConfigured) return;

    final userMsg = AiChatMessage.user(
      '命令 `$command` 执行失败 (exit code $exitCode):\n$errorOutput',
      type: AiMessageType.errorDiagnosis,
    );
    _chatHistory.add(userMsg);

    final assistantMsg = AiChatMessage.assistant(
      type: AiMessageType.errorDiagnosis,
    );
    _chatHistory.add(assistantMsg);

    _isStreaming = true;
    notifyListeners();

    try {
      final result = await AiService.diagnoseError(
        config: _config,
        command: command,
        errorOutput: errorOutput,
        exitCode: exitCode,
        cwd: cwd,
        shellType: shellType,
      );

      final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
      if (idx >= 0) {
        _chatHistory[idx] = _chatHistory[idx].copyWith(
          content: result,
          isStreaming: false,
        );
      }
      _isStreaming = false;
      notifyListeners();
      _saveHistory();
    } on AiException catch (e) {
      final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
      if (idx >= 0) {
        _chatHistory[idx] = _chatHistory[idx].copyWith(
          isStreaming: false,
          error: e.message,
        );
      }
      _isStreaming = false;
      _lastError = e.message;
      notifyListeners();
    }
  }

  /// 解释命令
  Future<void> explainCommand(String command) async {
    if (!isConfigured) return;

    final userMsg = AiChatMessage.user(
      '解释这个命令: $command',
      type: AiMessageType.explanation,
    );
    _chatHistory.add(userMsg);

    final assistantMsg = AiChatMessage.assistant(
      type: AiMessageType.explanation,
    );
    _chatHistory.add(assistantMsg);

    _isStreaming = true;
    notifyListeners();

    try {
      final result = await AiService.explainCommand(
        config: _config,
        command: command,
      );

      final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
      if (idx >= 0) {
        _chatHistory[idx] = _chatHistory[idx].copyWith(
          content: result,
          isStreaming: false,
        );
      }
      _isStreaming = false;
      notifyListeners();
      _saveHistory();
    } on AiException catch (e) {
      final idx = _chatHistory.indexWhere((m) => m.id == assistantMsg.id);
      if (idx >= 0) {
        _chatHistory[idx] = _chatHistory[idx].copyWith(
          isStreaming: false,
          error: e.message,
        );
      }
      _isStreaming = false;
      _lastError = e.message;
      notifyListeners();
    }
  }

  /// Agent/LLM 回合记录
  final List<AiChatMessage> _agentMessages = [];

  /// 添加命令执行结果到聊天记录
  void addCommandResult(String command, String output, {int? exitCode}) {
    final resultContent = exitCode != null && exitCode != 0
        ? '`$command` exited with code $exitCode:\n```\n$output\n```'
        : '```\n\$ $command\n$output\n```';
    final msg = AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.system,
      content: resultContent,
      timestamp: DateTime.now(),
      type: AiMessageType.commandSuggestion,
    );
    _chatHistory.add(msg);
    notifyListeners();
    _saveHistory();
  }

  // ==================== Agent Loop ====================

  /// Agent 模式的循环执行
  /// 用户发一条消息 → Agent 自动循环调用工具直到完成
  /// toolExecutor 由调用方（terminal_screen）提供，用于执行 bash 命令
  Future<void> runAgentLoop(
    String goal, {
    String? cwd,
    String? shellType,
    required String Function(String name, Map<String, dynamic> input) toolExecutor,
  }) async {
    if (!isConfigured) {
      _lastError = 'AI is not configured';
      notifyListeners();
      return;
    }

    _isStreaming = true;
    _lastError = null;
    _agentMessages.clear();

    // 添加用户消息到历史
    final userMsg = AiChatMessage.user(goal, type: AiMessageType.agent);
    _chatHistory.add(userMsg);

    // 添加助手消息占位
    final assistantMsg = AiChatMessage.assistant(type: AiMessageType.agent);
    _chatHistory.add(assistantMsg);
    notifyListeners();

    final basePrompt = _config.resolveSystemPrompt(
      shellType: shellType,
      cwd: cwd,
    );
    final systemPrompt = '$basePrompt\n\n'
        'You are an autonomous terminal agent. Use tools to accomplish the user\'s goal.\n'
        'Execute commands step by step. After each command, analyze the output and decide the next step.\n'
        'Be efficient — combine commands where possible.';

    // Agent 循环：最多 20 轮
    for (var turn = 0; turn < 20; turn++) {
      try {
        final result = await AiService.agentTurn(
          config: _config,
          messages: _agentMessages,
          systemPromptOverride: systemPrompt,
        );

        // 更新助手消息：显示思考 + 文本
        _updateAssistantMessage(assistantMsg.id,
          content: result.text, thinking: result.thinking);

        if (!result.hasToolCalls) {
          // 没有工具调用，结束
          break;
        }

        // 执行每个工具调用
        final toolResults = <AiToolResult>[];
        for (final call in result.toolCalls) {
          // 记录 assistant 的 tool_use
          _agentMessages.add(AiChatMessage.assistantWithToolCalls(
            [call],
            type: AiMessageType.agent,
          ));

          // 追加用户消息（工具结果）
          final output = result.stopReason == 'tool_use'
              ? AiService.executeTool(call.name, call.input, toolExecutor)
              : AiService.executeTool(call.name, call.input, defaultToolExecutor);

          // 在聊天中显示工具调用和结果
          _addToolResult(assistantMsg.id, call.name, call.input, output);

          toolResults.add(AiToolResult(
            toolCallId: call.id,
            output: output,
          ));
        }

        // 追加工具结果到 agent 消息列表
        _agentMessages.add(AiChatMessage.userWithToolResults(toolResults));

      } on AiException catch (e) {
        _updateAssistantMessage(assistantMsg.id, error: e.message);
        _lastError = e.message;
        break;
      } catch (e) {
        _updateAssistantMessage(assistantMsg.id, error: e.toString());
        _lastError = e.toString();
        break;
      }
    }

    _isStreaming = false;
    _finalizeStreaming(assistantMsg.id);
  }

  /// 更新助手消息内容
  void _updateAssistantMessage(
    String msgId, {
    String? content,
    String? thinking,
    String? error,
  }) {
    final idx = _chatHistory.indexWhere((m) => m.id == msgId);
    if (idx < 0) return;

    final current = _chatHistory[idx];
    _chatHistory[idx] = current.copyWith(
      content: content ?? current.content,
      thinking: thinking ?? current.thinking,
      error: error,
      isStreaming: error == null && content == null && thinking == null,
    );
    notifyListeners();
  }

  /// 在聊天中添加工具调用结果
  void _addToolResult(
    String assistantMsgId,
    String toolName,
    Map<String, dynamic> input,
    String output,
  ) {
    final cmd = input['command'] as String? ?? input['path'] as String? ?? toolName;
    final resultMsg = AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.system,
      content: '> $toolName: ${cmd.length > 60 ? '${cmd.substring(0, 60)}...' : cmd}\n$output',
      timestamp: DateTime.now(),
      type: AiMessageType.agent,
    );
    _chatHistory.add(resultMsg);
    notifyListeners();
  }

  /// 取消当前 Agent 执行
  void cancelAgentLoop() {
    _isStreaming = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    for (var i = _chatHistory.length - 1; i >= 0; i--) {
      if (_chatHistory[i].role == AiMessageRole.assistant &&
          _chatHistory[i].isStreaming) {
        _chatHistory[i] = _chatHistory[i].copyWith(isStreaming: false);
        break;
      }
    }
    notifyListeners();
  }

  /// 取消当前流式响应
  void cancelStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isStreaming = false;

    // 标记最后一条助手消息为已完成
    for (var i = _chatHistory.length - 1; i >= 0; i--) {
      if (_chatHistory[i].role == AiMessageRole.assistant &&
          _chatHistory[i].isStreaming) {
        _chatHistory[i] = _chatHistory[i].copyWith(isStreaming: false);
        break;
      }
    }
    notifyListeners();
  }

  /// 清空聊天记录
  Future<void> clearHistory() async {
    cancelStreaming();
    _chatHistory.clear();
    await _prefs.remove('ai_chat_history');
    notifyListeners();
  }

  // ==================== Private helpers ====================

  /// 根据当前模式增强系统提示词
  String _buildModePrompt(String basePrompt) {
    switch (_currentMode) {
      case AiMode.chat:
        return basePrompt;
      case AiMode.agent:
        return '$basePrompt\n\n'
            '[Agent Mode] You are an autonomous terminal agent. '
            'To accomplish the user\'s goal, generate shell commands one at a time. '
            'After each command, analyze the output and decide the next step. '
            'Wrap each command in a ```bash code fence so it can be extracted and executed. '
            'Explain your reasoning briefly before each command.';
      case AiMode.plan:
        return '$basePrompt\n\n'
            '[Plan Mode] You are a planning assistant. '
            'Break down the user\'s request into a numbered step-by-step plan of shell commands. '
            'Do NOT execute anything — only output the plan. '
            'For each step, show the command in a ```bash code fence and explain what it does. '
            'Wait for the user to approve before suggesting execution.';
    }
  }

  void _finalizeStreaming(String messageId) {
    _isStreaming = false;
    final idx = _chatHistory.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      _chatHistory[idx] = _chatHistory[idx].copyWith(isStreaming: false);
    }
    notifyListeners();
    _saveHistory();
  }

  /// 构建上下文消息（最近 N 条，排除空的流式消息）
  List<AiChatMessage> _buildContextMessages() {
    final messages = <AiChatMessage>[];
    var count = 0;
    for (var i = _chatHistory.length - 1; i >= 0 && count < 20; i--) {
      final msg = _chatHistory[i];
      // 跳过当前正在流式的消息（最后一条助手消息）
      if (msg.isStreaming) continue;
      if (msg.content.isEmpty) continue;
      messages.insert(0, msg);
      count++;
    }
    return messages;
  }

  /// 清理命令字符串（移除 markdown 代码围栏等）
  String _cleanCommand(String raw) {
    var cmd = raw.trim();
    // 移除 ```bash ... ``` 围栏
    if (cmd.startsWith('```')) {
      final firstNewline = cmd.indexOf('\n');
      if (firstNewline >= 0) {
        cmd = cmd.substring(firstNewline + 1);
      }
      final lastFence = cmd.lastIndexOf('```');
      if (lastFence >= 0) {
        cmd = cmd.substring(0, lastFence);
      }
      cmd = cmd.trim();
    }
    // 移除行内 ` 号
    if (cmd.startsWith('`') && cmd.endsWith('`') && !cmd.contains('\n')) {
      cmd = cmd.substring(1, cmd.length - 1).trim();
    }
    return cmd;
  }

  void _loadHistory() {
    final jsonStr = _prefs.getString('ai_chat_history');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List;
        _chatHistory.clear();
        for (final item in list) {
          _chatHistory
              .add(AiChatMessage.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        _chatHistory.clear();
      }
    }
  }

  Future<void> _saveHistory() async {
    // 只保留最近的消息
    if (_chatHistory.length > _maxHistoryLength) {
      _chatHistory.removeRange(0, _chatHistory.length - _maxHistoryLength);
    }
    try {
      final jsonStr = jsonEncode(_chatHistory.map((m) => m.toJson()).toList());
      await _prefs.setString('ai_chat_history', jsonStr);
    } catch (_) {
      // 持久化失败不致命
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
