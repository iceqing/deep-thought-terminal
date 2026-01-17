import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../shell/shell_session.dart';

/// 终端会话模型
/// 参考 termux-app: TerminalSession.java
class TerminalSession {
  final String id;
  final Terminal terminal;
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
    final terminal = Terminal(maxLines: 10000);
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
      terminal.onOutput = (String data) {
        if (_shellSession != null && _isRunning) {
          _shellSession!.write(data);
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
      terminal.write(text);
      _onTextChanged?.call();
    } catch (e) {
      terminal.write(utf8.decode(data, allowMalformed: true));
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
