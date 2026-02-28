import 'package:flutter/material.dart';
import '../models/terminal_session.dart';

/// 终端会话状态管理
/// 参考 termux-app: TermuxService.java, TermuxSessionsListViewController.java
class TerminalProvider extends ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _currentIndex = -1;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get sessionCount => _sessions.length;
  int get currentIndex => _currentIndex;

  TerminalSession? get currentSession {
    if (_currentIndex >= 0 && _currentIndex < _sessions.length) {
      return _sessions[_currentIndex];
    }
    return null;
  }

  /// 创建新会话
  Future<TerminalSession> createSession({
    String? title,
    bool isSshSession = false,
  }) async {
    final session = TerminalSession.create(
      title: title ?? 'Terminal ${_sessions.length + 1}',
      isSshSession: isSshSession,
    );

    // 启动Shell进程
    await session.start();

    _sessions.add(session);
    _currentIndex = _sessions.length - 1;
    _updateActiveState();
    notifyListeners();
    return session;
  }

  /// 切换到指定会话
  void switchToSession(int index) {
    if (index >= 0 && index < _sessions.length) {
      _currentIndex = index;
      _updateActiveState();
      notifyListeners();
    }
  }

  /// 切换到指定会话（通过 ID）
  void switchToSessionById(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      switchToSession(index);
    }
  }

  /// 关闭会话
  void closeSession(int index) {
    if (index < 0 || index >= _sessions.length) return;

    _sessions.removeAt(index);

    if (_sessions.isEmpty) {
      _currentIndex = -1;
    } else if (_currentIndex >= _sessions.length) {
      _currentIndex = _sessions.length - 1;
    } else if (_currentIndex > index) {
      _currentIndex--;
    }

    _updateActiveState();
    notifyListeners();
  }

  /// 关闭会话（通过 ID）
  void closeSessionById(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      closeSession(index);
    }
  }

  /// 关闭当前会话
  void closeCurrentSession() {
    if (_currentIndex >= 0) {
      closeSession(_currentIndex);
    }
  }

  /// 重命名会话
  void renameSession(int index, String newTitle) {
    if (index >= 0 && index < _sessions.length) {
      _sessions[index].title = newTitle;
      notifyListeners();
    }
  }

  /// 重命名当前会话
  void renameCurrentSession(String newTitle) {
    if (_currentIndex >= 0) {
      renameSession(_currentIndex, newTitle);
    }
  }

  /// 切换到下一个会话
  void nextSession() {
    if (_sessions.length > 1) {
      switchToSession((_currentIndex + 1) % _sessions.length);
    }
  }

  /// 切换到上一个会话
  void previousSession() {
    if (_sessions.length > 1) {
      switchToSession(
          (_currentIndex - 1 + _sessions.length) % _sessions.length);
    }
  }

  /// 更新活跃状态
  void _updateActiveState() {
    for (int i = 0; i < _sessions.length; i++) {
      _sessions[i].isActive = (i == _currentIndex);
    }
  }

  /// 清除当前终端内容
  void clearCurrentTerminal() {
    final session = currentSession;
    if (session == null) return;

    // 清除终端缓冲区
    session.terminal.eraseDisplay();
    session.terminal.eraseScrollbackOnly();
    session.terminal.setCursor(0, 0);

    notifyListeners();
  }

  /// 初始化（创建第一个会话）
  void init() {
    if (_sessions.isEmpty) {
      createSession();
    }
  }
}
