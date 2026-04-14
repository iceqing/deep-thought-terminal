import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
// 使用修改版 Terminal，支持 Termux 兼容的 wcwidth
import '../core/terminal.dart';
import '../core/terminal_controller.dart';
import '../shell/shell_session.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 输入修饰符转换函数类型
typedef InputModifierTransformer = String Function(String input);

/// 终端会话模型
/// 参考 termux-app: TerminalSession.java
class TerminalSession {
  static const String _cwdProbeCommand =
      ' printf "\\033]7777;cwd:%s\\007" "\$PWD"\r';
  static final RegExp _cwdProbeEchoPattern = RegExp(
    r'(^|\r?\n)\s*printf "\\033\]7777;cwd:%s\\007" "\$PWD"\r?\n?',
    multiLine: true,
  );

  final String id;
  // 使用 TermuxTerminal 以支持 Termux 兼容的 wcwidth
  final TermuxTerminal terminal;
  final TermuxTerminalController controller;
  final ScrollController scrollController;
  final bool isSshSession;
  String title;
  final DateTime createdAt;
  bool _isActive = false;

  // Shell进程连接
  ShellSession? _shellSession;
  bool _isRunning = false;
  int? _exitCode;

  // 输入输出处理订阅
  StreamSubscription? _outputSubscription;
  StreamSubscription? _exitSubscription;

  // 状态变化回调
  VoidCallback? _onTextChanged;
  VoidCallback? _onSessionFinished;

  // 输入修饰符转换器 - 用于处理 Ctrl/Alt 修饰键
  InputModifierTransformer? inputTransformer;

  // 命令执行回调 - 用于将命令保存到后端
  void Function(String command, String sessionName)? onCommandExecuted;

  // AI 命令请求回调 - 当用户输入 ?? 前缀时触发
  void Function(String query)? onAiCommandRequested;

  // 命令完成回调 - 包含退出码，用于自动错误诊断
  void Function(String command, int exitCode)? onCommandFinished;

  // 输入缓冲区 - 跟踪用户输入以检测命令
  String _inputBuffer = '';
  bool _inEscapeSequence = false;
  String? _lastReportedCommand;
  DateTime? _lastReportedAt;

  // 输出捕获 - 用于 AI 命令结果
  StringBuffer? _outputCaptureBuffer;
  void Function(String output)? _outputCaptureCallback;

  // 调试信息：最后发送给 shell 的尺寸
  int? lastShellColumns;
  int? lastShellRows;
  String? _lastKnownWorkingDirectory;

  /// Last known working directory, updated via OSC 7777 cwd reports.
  String? get lastKnownCwd => _lastKnownWorkingDirectory;
  Completer<String?>? _cwdRequestCompleter;

  TerminalSession({
    required this.id,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    this.isSshSession = false,
    this.title = 'Terminal',
  }) : createdAt = DateTime.now();

  bool get isActive => _isActive;
  bool get isRunning => _isRunning;
  int? get exitCode => _exitCode;

  set isActive(bool value) {
    _isActive = value;
  }

  /// 创建新的终端会话
  static TerminalSession create({String? title, bool isSshSession = false}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    // 使用 TermuxTerminal 替代 xterm 的 Terminal
    final terminal = TermuxTerminal(maxLines: 10000);
    final controller = TermuxTerminalController();
    final scrollController = ScrollController();

    return TerminalSession(
      id: id,
      terminal: terminal,
      controller: controller,
      scrollController: scrollController,
      isSshSession: isSshSession,
      title: title ?? 'Terminal',
    );
  }

  /// 启动Shell进程
  Future<void> start({
    int? columns,
    int? rows,
    String? workingDirectory,
  }) async {
    if (_isRunning) return;

    // 使用终端当前的实际尺寸，如果没有则使用默认值
    final actualColumns = columns ?? terminal.viewWidth;
    final actualRows = rows ?? terminal.viewHeight;

    try {
      // 创建并启动Shell会话
      _shellSession = await ShellSessionFactory.createInteractiveSession(
        workingDirectory: workingDirectory,
      );

      // 设置终端输出回调 - 将xterm的输出发送到Shell进程
      // 如果设置了inputTransformer，先转换输入（用于Ctrl/Alt修饰键）
      terminal.onOutput = (String data) {
        if (_shellSession != null && _isRunning) {
          // 跟踪用户输入以检测命令执行（在发送到shell之前）
          _trackInput(data);

          final transformedData =
              inputTransformer != null ? inputTransformer!(data) : data;
          _shellSession!.write(transformedData);
        }
      };

      // 设置终端大小调整回调 - 将resize信号传递给Shell进程
      // 这样vim等全屏应用才能正确响应屏幕大小变化
      terminal.onResize =
          (int width, int height, int pixelWidth, int pixelHeight) {
        if (_shellSession != null && _isRunning) {
          _shellSession!.resize(width, height);
          lastShellColumns = width;
          lastShellRows = height;
        }
      };

      // 监听Shell输出
      _outputSubscription = _shellSession!.onOutput.listen(
        (data) => _handleOutput(data),
        onError: (error) {
          _handleError(error.toString());
        },
      );

      // 监听Shell退出
      _exitSubscription = _shellSession!.onExit.listen(
        (_) => _handleExit(),
      );

      // 启动进程 - 使用实际的终端尺寸
      await _shellSession!.start(columns: actualColumns, rows: actualRows);
      _isRunning = true;
      lastShellColumns = actualColumns;
      lastShellRows = actualRows;

      // 确保 shell 获取到正确的终端尺寸
      // 有时候视图布局在 start() 之后才完成，需要额外发送一次 resize
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_shellSession != null && _isRunning) {
          _shellSession!.resize(terminal.viewWidth, terminal.viewHeight);
          lastShellColumns = terminal.viewWidth;
          lastShellRows = terminal.viewHeight;
        }
      });
    } catch (e) {
      _handleError('Failed to start shell: $e');
      rethrow;
    }
  }

  /// 停止Shell进程
  void stop() {
    _shellSession?.close();
    _cleanup();
  }

  /// 调整终端大小
  void resize(int columns, int rows) {
    _shellSession?.resize(columns, rows);
  }

  void _cleanup() {
    if (_cwdRequestCompleter != null && !_cwdRequestCompleter!.isCompleted) {
      _cwdRequestCompleter!.complete(
        _lastKnownWorkingDirectory ?? TermuxConstants.homeDir,
      );
    }
    _cwdRequestCompleter = null;
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _exitSubscription?.cancel();
    _exitSubscription = null;
    _shellSession = null;
    _isRunning = false;
  }

  /// 处理Shell输出
  void _handleOutput(List<int> data) {
    try {
      final text = utf8.decode(data, allowMalformed: true);

      // 检测自定义 OSC 序列: ESC ] 7777 ; command BEL
      // 用于与 Flutter 应用通信
      final oscPattern = RegExp(r'\x1b\]7777;([^\x07]+)\x07');
      final matches = oscPattern.allMatches(text).toList();
      for (final match in matches) {
        _handleOscCommand(match.group(1));
      }

      final cleanText =
          text.replaceAll(oscPattern, '').replaceAll(_cwdProbeEchoPattern, '');
      if (cleanText.isNotEmpty) {
        terminal.write(cleanText);
      }

      // Append to capture buffer if active (strip ANSI for clean output)
      if (_outputCaptureBuffer != null && _outputCaptureBuffer!.length < 4096) {
        final clean = text
            .replaceAll(RegExp(r'\x1b\[[0-9;]*[a-zA-Z]'), '')
            .replaceAll(RegExp(r'\x1b\][^\x07]*\x07'), '');
        _outputCaptureBuffer!.write(clean);
      }

      _onTextChanged?.call();
    } catch (e) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    }
  }

  /// 处理自定义 OSC 命令
  void _handleOscCommand(String? command) {
    if (command == null) return;

    if (command.startsWith('command:')) {
      final cmd = command.substring(8).trim();
      if (cmd.isNotEmpty) {
        _emitCommandExecuted(cmd);
      }
      return;
    }

    if (command.startsWith('cwd:')) {
      final cwd = command.substring(4).trim();
      if (cwd.isNotEmpty) {
        _lastKnownWorkingDirectory = cwd;
      }
      if (_cwdRequestCompleter != null && !_cwdRequestCompleter!.isCompleted) {
        _cwdRequestCompleter!.complete(
          _lastKnownWorkingDirectory ?? TermuxConstants.homeDir,
        );
      }
      return;
    }

    switch (command) {
      case 'setup-storage':
        _setupStorage();
        break;
      default:
        debugPrint('Unknown OSC command: $command');
    }
  }

  /// 执行存储设置
  Future<void> _setupStorage() async {
    final homePath = TermuxConstants.homeDir;

    try {
      final result = await StorageService.instance.setupStorage(homePath);

      // 输出结果到终端
      terminal.write('\r\n');
      if (result.success) {
        terminal.write('\x1b[32m'); // 绿色
        terminal.write('Storage setup completed successfully!\r\n');
        terminal.write('\x1b[0m'); // 重置颜色
        terminal.write('\r\nCreated symlinks in ~/storage:\r\n');
        for (final link in result.created) {
          final parts = link.split(' -> ');
          if (parts.length == 2) {
            final name = parts[0].split('/').last;
            terminal.write('  $name -> ${parts[1]}\r\n');
          }
        }
        terminal.write(
            '\r\nYou can now access external storage via ~/storage/\r\n');
      } else {
        terminal.write('\x1b[31m'); // 红色
        terminal.write('Storage setup failed!\r\n');
        terminal.write('\x1b[0m'); // 重置颜色
        for (final error in result.errors) {
          terminal.write('  Error: $error\r\n');
        }
      }
      terminal.write('\r\n');
      _onTextChanged?.call();
    } catch (e) {
      terminal.write('\r\n\x1b[31mStorage setup error: $e\x1b[0m\r\n');
      _onTextChanged?.call();
    }
  }

  /// 处理错误
  void _handleError(String message) {
    terminal.write('\r\n\x1b[31mError: $message\x1b[0m\r\n');
    _onTextChanged?.call();
  }

  /// 处理Shell退出
  void _handleExit() {
    _isRunning = false;
    _exitCode = _shellSession?.exitCode;

    // 触发命令完成回调（用于自动错误诊断）
    if (_lastReportedCommand != null && _exitCode != null && _exitCode != 0) {
      onCommandFinished?.call(_lastReportedCommand!, _exitCode!);
    }

    // 显示退出信息
    terminal.write('\r\n\x1b[33m[Process completed');
    if (_exitCode != null) {
      if (_exitCode! > 0) {
        terminal.write(' (code ${_exitCode})');
      } else if (_exitCode! < 0) {
        terminal.write(' (signal ${-_exitCode!})');
      }
    }
    terminal.write(' - press Enter to restart]\x1b[0m\r\n');

    _onTextChanged?.call();
    _onSessionFinished?.call();

    _cleanup();
  }

  /// 写入欢迎消息
  void _writeWelcomeMessage() {
    // 使用cat时不需要欢迎消息，直接等待输入
  }

  /// 跟踪用户输入，检测命令执行（按下 Enter）
  void _trackInput(String data) {
    // 如果是终端自动响应，跳过
    if (_isTerminalResponse(data)) return;

    debugPrint('[HistoryDiag] trackInput chunk="$data"');

    // 如果是提示符或输出，清空缓冲区
    if (_isPromptOrOutput(data)) {
      _inputBuffer = '';
      return;
    }

    for (final char in data.codeUnits) {
      if (_inEscapeSequence) {
        if (char >= 0x40 && char <= 0x7E) {
          _inEscapeSequence = false;
        }
        continue;
      }

      if (char == 0x1B) {
        _inEscapeSequence = true;
        continue;
      }

      // 跳过大部分控制字符
      if (char < 0x20 &&
          char != 0x0D &&
          char != 0x08 &&
          char != 0x03 &&
          char != 0x15 &&
          char != 0x07) {
        continue;
      }

      if (char == 0x0D || char == 0x0A) {
        final cmd = _inputBuffer.trim();
        debugPrint('[HistoryDiag] trackInput enter, buffer="$cmd"');
        if (cmd.isNotEmpty && _isValidCommand(cmd)) {
          _emitCommandExecuted(cmd);
        }
        _inputBuffer = '';
      } else if (char == 0x7F || char == 0x08) {
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
        }
      } else if (char == 0x03 || char == 0x15) {
        _inputBuffer = '';
      } else if (char >= 0x20) {
        _inputBuffer += String.fromCharCode(char);
      }
    }
  }

  /// 检查是否是终端自动响应
  bool _isTerminalResponse(String data) {
    if (data.isEmpty) return true;

    // 回车/退格/Ctrl+C/Ctrl+U 这类控制输入属于用户输入，不应被当作终端响应跳过
    final hasInputControl = data.codeUnits.any(
      (c) =>
          c == 0x0D ||
          c == 0x0A ||
          c == 0x08 ||
          c == 0x7F ||
          c == 0x03 ||
          c == 0x15,
    );
    if (hasInputControl) return false;

    final hasPrintable = data.codeUnits.any((c) => c >= 0x20 && c != 0x7F);
    if (!hasPrintable) return true;
    if (data.startsWith('\x1b[')) return true;
    return false;
  }

  /// 检查是否是提示符或输出
  bool _isPromptOrOutput(String data) {
    if (data.isEmpty) return false;
    final trimmed = data.trim();
    if (trimmed.isEmpty) return false;
    final hasPrompt =
        RegExp(r'[\$\#\>]\s*$|@.*:.*[\$\#\>]\s*$').hasMatch(trimmed);
    if (hasPrompt && _inputBuffer.isNotEmpty) return true;
    final hasOnlyControl =
        !trimmed.codeUnits.any((c) => c >= 0x20 && c != 0x7F);
    return hasOnlyControl;
  }

  /// 检查是否是有效命令
  bool _isValidCommand(String cmd) {
    if (cmd.isEmpty) return false;
    if (cmd.startsWith('~') || cmd.startsWith(r'$') || cmd.startsWith('#'))
      return false;
    if (cmd.contains(':~') || cmd.contains(':/')) return false;
    if (cmd.length < 2) return false;
    return true;
  }

  void _emitCommandExecuted(String cmd) {
    // 去重：同一命令在短时间内可能由键盘跟踪和 shell hook 同时上报
    final now = DateTime.now();
    if (_lastReportedCommand == cmd &&
        _lastReportedAt != null &&
        now.difference(_lastReportedAt!).inMilliseconds < 600) {
      return;
    }
    _lastReportedCommand = cmd;
    _lastReportedAt = now;

    // AI 命令拦截：检测 ?? 前缀
    if (cmd.startsWith('??')) {
      final query = cmd.substring(2).trim();
      if (query.isNotEmpty) {
        onAiCommandRequested?.call(query);
      }
      return;
    }

    onCommandExecuted?.call(cmd, displayName);
  }

  /// 写入文本到Shell
  void write(String text) {
    if (_shellSession != null && _isRunning) {
      _shellSession!.write(text);
    }
  }

  /// 开始捕获输出（用于 AI 命令结果展示）
  void startOutputCapture(void Function(String output) callback) {
    _outputCaptureBuffer = StringBuffer();
    _outputCaptureCallback = callback;
  }

  /// 停止捕获并通过回调返回结果
  void stopOutputCapture() {
    final buffer = _outputCaptureBuffer;
    final callback = _outputCaptureCallback;
    _outputCaptureBuffer = null;
    _outputCaptureCallback = null;
    if (buffer != null && callback != null) {
      callback(buffer.toString());
    }
  }

  /// 获取当前 shell 工作目录
  Future<String> queryCurrentWorkingDirectory({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final fallbackPath = _lastKnownWorkingDirectory ?? TermuxConstants.homeDir;
    if (_shellSession == null || !_isRunning) {
      return fallbackPath;
    }

    if (_cwdRequestCompleter != null && !_cwdRequestCompleter!.isCompleted) {
      return _cwdRequestCompleter!.future
          .timeout(
            timeout,
            onTimeout: () => fallbackPath,
          )
          .then((value) =>
              value?.trim().isNotEmpty == true ? value!.trim() : fallbackPath);
    }

    final completer = Completer<String?>();
    _cwdRequestCompleter = completer;

    // 通过内部 probe 请求 shell 回传 PWD。
    // 这里故意加前导空格，避免 bash HISTCONTROL 记录到历史里。
    write(_cwdProbeCommand);

    try {
      final cwd = await completer.future.timeout(
        timeout,
        onTimeout: () => fallbackPath,
      );
      final normalized = cwd?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        _lastKnownWorkingDirectory = normalized;
        return normalized;
      }
      return fallbackPath;
    } finally {
      if (identical(_cwdRequestCompleter, completer)) {
        _cwdRequestCompleter = null;
      }
    }
  }

  /// 写入字节数据到Shell
  void writeBytes(List<int> data) {
    if (_shellSession != null && _isRunning) {
      _shellSession!.writeBytes(data);
    }
  }

  /// 重置终端
  void reset() {
    terminal.resetCursorStyle();
    terminal.resetForeground();
    terminal.resetBackground();
    terminal.clearAltBuffer();
    _writeWelcomeMessage();
    _onTextChanged?.call();
  }

  /// 设置文本变化回调
  set onTextChanged(VoidCallback? callback) {
    _onTextChanged = callback;
  }

  /// 设置会话结束回调
  set onSessionFinished(VoidCallback? callback) {
    _onSessionFinished = callback;
  }

  /// 获取会话显示名称
  String get displayName => title.isNotEmpty ? title : 'Session $id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
