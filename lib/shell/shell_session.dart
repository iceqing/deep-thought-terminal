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
  /// 检查bash是否已安装
  static Future<bool> isBashInstalled() async {
    final bashFile = File(TermuxConstants.bashPath);
    return await bashFile.exists();
  }

  /// 创建交互式Shell会话
  /// 在Android上，使用系统shell来启动bash，确保LD_LIBRARY_PATH正确设置
  static Future<PtyShellSession> createInteractiveSession({
    String? shellPath,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    // 使用HOME目录作为默认工作目录
    String? workDir = workingDirectory;
    if (workDir == null && Platform.isAndroid) {
      final homeDir = Directory(TermuxConstants.homeDir);
      if (await homeDir.exists()) {
        workDir = TermuxConstants.homeDir;
      } else {
        workDir = '/sdcard';
      }
    }

    if (Platform.isAndroid) {
      // 检查bash是否安装
      if (await isBashInstalled()) {
        final cmd = _buildBashLaunchCommand();
        debugPrint('Bash installed, using wrapper approach');
        debugPrint('Shell command: $cmd');
        debugPrint('Lib dir: ${TermuxConstants.libDir}');

        // 验证库文件存在
        final libReadline = File('${TermuxConstants.libDir}/libreadline.so.8');
        final libReadline83 = File('${TermuxConstants.libDir}/libreadline.so.8.3');
        debugPrint('libreadline.so.8 exists: ${await libReadline.exists()}');
        debugPrint('libreadline.so.8.3 exists: ${await libReadline83.exists()}');

        // 使用系统shell来启动bash，这样可以确保环境变量正确设置
        // 因为Termux的bash二进制文件有硬编码的RUNPATH指向/data/data/com.termux/
        // 我们需要通过LD_LIBRARY_PATH覆盖它
        return PtyShellSession(
          shellPath: '/system/bin/sh',
          arguments: ['-c', cmd],
          workingDirectory: workDir,
          environment: environment,
        );
      } else {
        debugPrint('Bash not found, using system shell');
        return PtyShellSession(
          shellPath: '/system/bin/sh',
          arguments: [],
          workingDirectory: workDir,
          environment: environment,
        );
      }
    }

    // Linux/其他平台
    final shell = shellPath ?? await _getDesktopShell();
    List<String> args = [];
    if (shell.endsWith('bash') || shell.endsWith('zsh')) {
      args = ['--login'];
    }

    return PtyShellSession(
      shellPath: shell,
      arguments: args,
      workingDirectory: workDir,
      environment: environment,
    );
  }

  /// 构建启动bash的命令
  /// 设置LD_LIBRARY_PATH来覆盖硬编码的RUNPATH
  static String _buildBashLaunchCommand() {
    final libPath = TermuxConstants.libDir;
    final bashPath = TermuxConstants.bashPath;
    final homePath = TermuxConstants.homeDir;
    final prefixPath = TermuxConstants.prefixDir;
    final binPath = TermuxConstants.binDir;
    final tmpPath = TermuxConstants.tmpDir;

    // 使用export确保环境变量被正确设置
    // 用分号分隔多个命令，确保与Android的sh兼容
    return 'export LD_LIBRARY_PATH="$libPath"; '
        'export HOME="$homePath"; '
        'export PREFIX="$prefixPath"; '
        'export PATH="$binPath:/system/bin:/system/xbin"; '
        'export TMPDIR="$tmpPath"; '
        'export TERM="xterm-256color"; '
        'export LANG="en_US.UTF-8"; '
        'export SHELL="$bashPath"; '
        'cd "\$HOME" 2>/dev/null || cd /sdcard; '
        'exec "$bashPath" --login';
  }

  /// 获取桌面平台的默认shell
  static Future<String> _getDesktopShell() async {
    final shells = ['/bin/bash', '/bin/zsh', '/bin/sh'];
    for (final shell in shells) {
      if (await File(shell).exists()) {
        return shell;
      }
    }
    return Platform.environment['SHELL'] ?? '/bin/sh';
  }
}
