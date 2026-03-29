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
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final StreamController<void> _exitController =
      StreamController<void>.broadcast();
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
    env['DPTERM_VERSION'] = '0.0.1';

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
      // flutter_pty 的 resize 参数顺序是 (rows, cols)，不是 (cols, rows)
      _pty!.resize(rows, columns);
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

  /// 检查指定的 shell 是否存在
  static Future<bool> isShellInstalled(String shellPath) async {
    final shellFile = File(shellPath);
    return await shellFile.exists();
  }

  /// 获取用户配置的默认 shell
  /// 优先级: 参数 > ~/.shell 文件 > bash
  static Future<String> getConfiguredShell({String? preferredShell}) async {
    // 1. 如果指定了 shell，检查是否存在
    if (preferredShell != null) {
      final shellPath = preferredShell.startsWith('/')
          ? preferredShell
          : '${TermuxConstants.binDir}/$preferredShell';
      if (await isShellInstalled(shellPath)) {
        debugPrint('Using preferred shell: $shellPath');
        return shellPath;
      }
    }

    // 2. 读取 ~/.shell 文件（chsh 创建的）
    try {
      final shellConfigFile = File('${TermuxConstants.homeDir}/.shell');
      if (await shellConfigFile.exists()) {
        final configuredShell = (await shellConfigFile.readAsString()).trim();
        if (configuredShell.isNotEmpty) {
          final shellPath = configuredShell.startsWith('/')
              ? configuredShell
              : '${TermuxConstants.binDir}/$configuredShell';
          if (await isShellInstalled(shellPath)) {
            debugPrint('Using shell from ~/.shell: $shellPath');
            return shellPath;
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading ~/.shell: $e');
    }

    // 3. 默认使用 bash
    debugPrint('Using default shell: ${TermuxConstants.bashPath}');
    return TermuxConstants.bashPath;
  }

  /// 创建交互式Shell会话
  /// 在Android上，使用系统shell来启动配置的shell，确保LD_LIBRARY_PATH正确设置
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
      // 检查 bootstrap 是否已安装
      if (await isBashInstalled()) {
        // 获取用户配置的 shell
        final configuredShell =
            await getConfiguredShell(preferredShell: shellPath);
        final cmd = _buildShellLaunchCommand(configuredShell);
        debugPrint('Using configured shell: $configuredShell');
        debugPrint('Shell command length: ${cmd.length}');

        // 使用系统shell来启动用户配置的shell
        // 因为Termux的二进制文件有硬编码的RUNPATH指向/data/data/com.termux/
        // 我们需要通过LD_LIBRARY_PATH覆盖它
        return PtyShellSession(
          shellPath: '/system/bin/sh',
          arguments: ['-c', cmd],
          workingDirectory: workDir,
          environment: environment,
        );
      } else {
        debugPrint('Bootstrap not found, using system shell');
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

  /// 构建启动 shell 的命令
  /// 支持 bash, zsh, fish 等不同 shell
  static String _buildShellLaunchCommand(String shellPath) {
    final libPath = TermuxConstants.libDir;
    final homePath = TermuxConstants.homeDir;
    final prefixPath = TermuxConstants.prefixDir;
    final binPath = TermuxConstants.binDir;
    final tmpPath = TermuxConstants.tmpDir;
    final etcPath = TermuxConstants.etcDir;
    final aptConfigPath = '$etcPath/apt/apt.conf';
    final caCertPath = '$etcPath/tls/cert.pem';

    // 获取 shell 名称
    final shellName = shellPath.split('/').last;

    // 基础环境变量（所有 shell 通用）
    final baseEnv = 'export LD_LIBRARY_PATH="$libPath"; '
        'export HOME="$homePath"; '
        'export PREFIX="$prefixPath"; '
        'export PATH="$binPath:/system/bin:/system/xbin"; '
        'export TMPDIR="$tmpPath"; '
        'export TERM="xterm-256color"; '
        'export TERMINFO="$prefixPath/share/terminfo"; '
        'export LANG="en_US.UTF-8"; '
        'export SHELL="$shellPath"; '
        'export APT_CONFIG="$aptConfigPath"; '
        'export SSL_CERT_FILE="$caCertPath"; '
        'export CURL_CA_BUNDLE="$caCertPath"; '
        'export GIT_SSL_CAINFO="$caCertPath"; '
        'export DPTERM_VERSION="0.0.1"; '
        'export CLICOLOR=1; '
        'export CLICOLOR_FORCE=1; '
        r"export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34:*.tar=1;31:*.gz=1;31:*.zip=1;31:*.jpg=1;35:*.png=1;35:*.mp3=1;36:*.mp4=1;36'; "
        r"export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'; "
        'export LESS="-R"; '
        'cd "\$HOME" 2>/dev/null || cd /sdcard; '
        // 确保所有 Android GID 都注册到 /etc/group，避免 proot-distro 等工具报
        // "id: cannot find name for group ID xxx" 的错误
        'for __gid in \$(id -G 2>/dev/null); do '
        'grep -q ":\$__gid:" "$etcPath/group" 2>/dev/null || '
        'echo "aid_\$__gid:x:\$__gid:" >> "$etcPath/group" 2>/dev/null; '
        'done; unset __gid; '
        // 确保当前 UID 在 /etc/passwd 中
        '__uid=\$(id -u 2>/dev/null); __gid_p=\$(id -g 2>/dev/null); '
        'grep -q ":\$__uid:" "$etcPath/passwd" 2>/dev/null || '
        'echo "u0_a\$((__uid % 100000)):x:\$__uid:\$__gid_p::/data/data/com.dpterm/files/home:$shellPath" >> "$etcPath/passwd" 2>/dev/null; '
        'unset __uid __gid_p; '
        // 自动修复常见脚本的 shebang（/usr/bin/env → $PREFIX/bin/env）
        'for __f in "\$HOME/.autojump/bin/"*; do '
        '[ -f "\$__f" ] && head -1 "\$__f" | grep -q "^#!/usr/bin" && '
        'sed -i "1s|#!/usr/bin/env|#!$binPath/env|;1s|#!/usr/bin/|#!$binPath/|;1s|#!/bin/|#!$binPath/|" "\$__f" 2>/dev/null; '
        'done; unset __f; ';

    // 根据不同 shell 构建启动命令
    switch (shellName) {
      case 'zsh':
        // Zsh: 使用 ZDOTDIR 或默认配置
        return baseEnv +
            'export ZDOTDIR="\$HOME"; '
                'if [ -f "\$HOME/.zshrc" ]; then exec "$shellPath"; '
                'else exec "$shellPath" --no-rcs; fi';

      case 'fish':
        // Fish: 配置文件在 ~/.config/fish/config.fish
        return baseEnv + 'exec "$shellPath"';

      case 'bash':
      default:
        // Bash: 使用 --rcfile 加载用户配置
        return baseEnv +
            // 历史记录配置（仅 bash）
            'export HISTFILE="\$HOME/.bash_history"; '
                'export HISTSIZE=10000; '
                'export HISTFILESIZE=20000; '
                'export HISTCONTROL=ignoredups:ignorespace:erasedups; '
                // PROMPT_COMMAND:
                // 1) 首次提示符时读取历史
                // 2) 每次命令后追加历史
                // 3) 获取最后一条命令并通过 OSC 7777 回传
                'export PROMPT_COMMAND=\''
                '[ -z "\$_DPTERM_HIST_INIT" ] && history -r && _DPTERM_HIST_INIT=1; '
                'history -a; '
                '__dpterm_last_cmd="\$(HISTTIMEFORMAT= history 1 | sed -n "1p" | sed -E "s/^ *[0-9]+ *//")"; '
                'if [ -n "\$__dpterm_last_cmd" ] && '
                '[ "\$__dpterm_last_cmd" != "\$_DPTERM_LAST_CMD" ] && '
                'case "\$__dpterm_last_cmd" in *7777\\;cwd:%s*) false;; *) true;; esac; '
                'then '
                'printf "\\033]7777;command:%s\\007" "\$__dpterm_last_cmd"; '
                '_DPTERM_LAST_CMD="\$__dpterm_last_cmd"; '
                'fi; '
                '\'; '
                r"export PS1='\[\e[0;32m\]\w\[\e[0m\] \$ '; "
                'if [ -f "\$HOME/.bashrc" ]; then exec "$shellPath" --rcfile "\$HOME/.bashrc"; '
                'else exec "$shellPath" --norc; fi';
    }
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
