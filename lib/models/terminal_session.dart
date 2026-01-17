import 'package:xterm/xterm.dart';

/// 终端会话模型
/// 参考 termux-app: TerminalSession.java
class TerminalSession {
  final String id;
  final Terminal terminal;
  final TerminalController controller;
  String title;
  final DateTime createdAt;
  bool _isActive = false;

  TerminalSession({
    required this.id,
    required this.terminal,
    required this.controller,
    this.title = 'Terminal',
  }) : createdAt = DateTime.now();

  bool get isActive => _isActive;

  set isActive(bool value) {
    _isActive = value;
  }

  /// 创建新的终端会话
  factory TerminalSession.create({String? title}) {
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

  /// 写入欢迎消息
  void writeWelcomeMessage() {
    terminal.write('Welcome to Deep Thought Terminal!\r\n');
    terminal.write('Session: $title\r\n');
    terminal.write('\$ ');
  }

  /// 写入文本
  void write(String text) {
    terminal.write(text);
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
