import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
// 使用修改版 Terminal，支持 Termux 兼容的 wcwidth
import '../core/terminal.dart';
import '../shell/shell_session.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 输入修饰符转换函数类型
typedef InputModifierTransformer = String Function(String input);

/// 终端会话模型
/// 参考 termux-app: TerminalSession.java
class TerminalSession {
  final String id;
  // 使用 TermuxTerminal 以支持 Termux 兼容的 wcwidth
  final TermuxTerminal terminal;
  final TerminalController controller;
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

  TerminalSession({
    required this.id,
    required this.terminal,
    required this.controller,
    this.title = 'Terminal',
  }) : createdAt = DateTime.now();

  bool get isActive => _isActive;
  bool get isRunning => _isRunning;
  int? get exitCode => _exitCode;

  set isActive(bool value) {
    _isActive = value;
  }

  /// 创建新的终端会话
  static TerminalSession create({String? title}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    // 使用 TermuxTerminal 替代 xterm 的 Terminal
    final terminal = TermuxTerminal(maxLines: 10000);
    final controller = TerminalController();

    return TerminalSession(
      id: id,
      terminal: terminal,
      controller: controller,
      title: title ?? 'Terminal',
    );
  }

  /// 启动Shell进程
  Future<void> start({int columns = 80, int rows = 24}) async {
    if (_isRunning) return;

    try {
      // 创建并启动Shell会话
      _shellSession = await ShellSessionFactory.createInteractiveSession();

      // 设置终端输出回调 - 将xterm的输出发送到Shell进程
      // 如果设置了inputTransformer，先转换输入（用于Ctrl/Alt修饰键）
      terminal.onOutput = (String data) {
        if (_shellSession != null && _isRunning) {
          final transformedData = inputTransformer != null
              ? inputTransformer!(data)
              : data;
          _shellSession!.write(transformedData);
        }
      };

      // 设置终端大小调整回调 - 将resize信号传递给Shell进程
      // 这样vim等全屏应用才能正确响应屏幕大小变化
      terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
        if (_shellSession != null && _isRunning) {
          _shellSession!.resize(width, height);
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

      // 启动进程
      await _shellSession!.start(columns: columns, rows: rows);
      _isRunning = true;
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
      final match = oscPattern.firstMatch(text);

      if (match != null) {
        final command = match.group(1);
        _handleOscCommand(command);
        // 移除 OSC 序列，不显示在终端中
        final cleanText = text.replaceAll(oscPattern, '');
        if (cleanText.isNotEmpty) {
          terminal.write(cleanText);
        }
      } else {
        terminal.write(text);
      }

      _onTextChanged?.call();
    } catch (e) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    }
  }

  /// 处理自定义 OSC 命令
  void _handleOscCommand(String? command) {
    if (command == null) return;

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
        terminal.write('\r\nYou can now access external storage via ~/storage/\r\n');
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

  /// 写入文本到Shell
  void write(String text) {
    if (_shellSession != null && _isRunning) {
      _shellSession!.write(text);
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
