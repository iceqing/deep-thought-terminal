import 'package:flutter/material.dart';
import '../models/terminal_session.dart';
import '../services/session_persistence_service.dart';

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

  /// 初始化：尝试恢复上次会话，若无则创建新会话
  Future<void> init() async {
    if (_sessions.isNotEmpty) return;

    final restored = await _restoreSessions();
    if (!restored) {
      await createSession();
    }
  }

  // Pattern to strip cwd probe echoes from saved buffer content
  static final _cwdProbePattern = RegExp(
    r'''^\s*printf "\\033\]7777;cwd:%s\\007" "\$PWD"\s*$''',
  );

  /// Save all session state to disk for later restoration.
  Future<void> saveSessions() async {
    if (_sessions.isEmpty) {
      await SessionPersistenceService.instance.clear();
      return;
    }

    final persisted = <PersistedSession>[];
    for (final session in _sessions) {
      // Extract buffer text
      final buffer = session.terminal.buffer;
      final lines = <String>[];
      for (int i = 0; i < buffer.lines.length; i++) {
        final line = buffer.lines[i].getText().trimRight();
        // Strip cwd probe echoes — these are internal and shouldn't be restored
        if (_cwdProbePattern.hasMatch(line)) continue;
        lines.add(line);
      }
      // Remove trailing empty lines
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      final text = lines.join('\n');

      // Use last known cwd directly — don't send a probe command that would
      // pollute the terminal buffer right before saving it.
      final cwd = session.lastKnownCwd;

      persisted.add(PersistedSession(
        id: session.id,
        title: session.title,
        isSshSession: session.isSshSession,
        bufferContent: text,
        workingDirectory: cwd,
      ));
    }

    await SessionPersistenceService.instance.save(PersistedState(
      sessions: persisted,
      activeIndex: _currentIndex,
    ));
  }

  /// Restore sessions from persisted state. Returns true if any were restored.
  Future<bool> _restoreSessions() async {
    final state = await SessionPersistenceService.instance.load();
    if (state == null || state.sessions.isEmpty) return false;

    for (final ps in state.sessions) {
      // Skip SSH sessions — can't reconnect automatically
      if (ps.isSshSession) continue;

      final session = TerminalSession.create(title: ps.title);

      // Write saved buffer content so user sees previous output
      if (ps.bufferContent.isNotEmpty) {
        // Convert \n to \r\n for terminal display
        final displayText = ps.bufferContent.replaceAll('\n', '\r\n');
        session.terminal.write(displayText);
        session.terminal.write('\r\n');
      }

      final restoredWorkingDirectory =
          (ps.workingDirectory?.trim().isNotEmpty ?? false)
              ? ps.workingDirectory!.trim()
              : null;

      // Start shell directly in the saved working directory so we don't
      // inject a visible `cd ...` command into the terminal buffer.
      await session.start(workingDirectory: restoredWorkingDirectory);

      _sessions.add(session);
    }

    if (_sessions.isEmpty) return false;

    _currentIndex = state.activeIndex.clamp(0, _sessions.length - 1);
    _updateActiveState();
    notifyListeners();

    // Clear persisted state after successful restore
    await SessionPersistenceService.instance.clear();
    return true;
  }
}
