import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../bootstrap/termux_bootstrap.dart';
import '../utils/constants.dart';

/// Shell会话连接接口
abstract class ShellSession {
  Future<void> start({int columns = 80, int rows = 24});
  void write(String data);
  void writeBytes(List<int> data);
  void resize(int columns, int rows);
  void close();
  bool get isRunning;
  int? get exitCode;
  Stream<List<int>> get onOutput;
  Stream<void> get onExit;
}

/// 使用flutter_pty的Shell会话实现
class PtyShellSession implements ShellSession {
  final String shellPath;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  Pty? _pty;
  final StreamController<List<int>> _outputController = StreamController<List<int>>.broadcast();
  final StreamController<void> _exitController = StreamController<void>.broadcast();
  bool _isRunning = false;
  int? _exitCode;

  PtyShellSession({
    required this.shellPath,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
  });

  @override
  bool get isRunning => _isRunning && _pty != null;

  @override
  int? get exitCode => _exitCode;

  @override
  Stream<List<int>> get onOutput => _outputController.stream;

  @override
  Stream<void> get onExit => _exitController.stream;

  @override
  Future<void> start({int columns = 80, int rows = 24}) async {
    // 使用Termux环境变量
    final env = TermuxEnvironment.getFullEnvironment();
    if (environment != null) {
      env.addAll(environment!);
    }

    env['TERM'] = 'xterm-256color';
    env['COLORTERM'] = 'truecolor';

    final workDir = workingDirectory ?? env['HOME'] ?? '/sdcard';

    try {
      debugPrint('Starting shell: $shellPath');
      debugPrint('Working directory: $workDir');
      debugPrint('PATH: ${env['PATH']}');

      _pty = Pty.start(
        shellPath,
        arguments: arguments,
        workingDirectory: workDir,
        environment: env,
        columns: columns,
        rows: rows,
      );

      _isRunning = true;

      _pty!.output.listen(
        (data) {
          if (!_outputController.isClosed) {
            _outputController.add(data);
          }
        },
        onError: (error) {
          if (!_outputController.isClosed) {
            _outputController.addError(error);
          }
        },
        onDone: () {
          _handleExit();
        },
      );

      _pty!.exitCode.then((code) {
        _exitCode = code;
        _handleExit();
      });
    } catch (e) {
      _isRunning = false;
      _outputController.addError(e);
      rethrow;
    }
  }

  @override
  void write(String data) {
    if (_pty != null && isRunning) {
      _pty!.write(utf8.encode(data));
    }
  }

  @override
  void writeBytes(List<int> data) {
    if (_pty != null && isRunning) {
      _pty!.write(Uint8List.fromList(data));
    }
  }

  @override
  void resize(int columns, int rows) {
    if (_pty != null && isRunning) {
      _pty!.resize(columns, rows);
    }
  }

  @override
  void close() {
    if (_pty != null) {
      _pty!.kill();
    }
    _handleExit();
  }

  void _handleExit() {
    if (_isRunning) {
      _isRunning = false;
      if (!_exitController.isClosed) {
        _exitController.add(null);
      }
      _outputController.close();
      _exitController.close();
    }
  }
}

/// Shell会话工厂
class ShellSessionFactory {
  /// 获取默认Shell路径
  static Future<String> getDefaultShell() async {
    if (Platform.isAndroid) {
      // Android上始终使用系统shell
      // 因为/data/data目录有noexec限制，无法直接执行bash
      return '/system/bin/sh';
    }

    // Linux/其他平台
    final shells = ['/bin/bash', '/bin/zsh', '/bin/sh'];
    for (final shell in shells) {
      if (await File(shell).exists()) {
        return shell;
      }
    }
    return Platform.environment['SHELL'] ?? '/bin/sh';
  }

  /// 创建交互式Shell会话
  static Future<PtyShellSession> createInteractiveSession({
    String? shellPath,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final shell = shellPath ?? await getDefaultShell();

    List<String> args = [];

    // 在Android上，使用系统shell但设置Termux环境
    // 这样可以使用PATH中的工具
    if (Platform.isAndroid) {
      // 不使用--login，因为系统sh可能不支持
    } else if (shell.endsWith('bash') || shell.endsWith('zsh')) {
      args = ['--login'];
    }

    // 使用HOME目录作为默认工作目录
    String? workDir = workingDirectory;
    if (workDir == null && Platform.isAndroid) {
      // 使用sdcard作为工作目录，因为home目录可能还没创建
      final homeDir = Directory(TermuxConstants.homeDir);
      if (await homeDir.exists()) {
        workDir = TermuxConstants.homeDir;
      } else {
        workDir = '/sdcard';
      }
    }

    return PtyShellSession(
      shellPath: shell,
      arguments: args,
      workingDirectory: workDir,
      environment: environment,
    );
  }
}
