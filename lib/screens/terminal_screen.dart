import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/task_provider.dart';
import '../services/api_service.dart';
import '../services/volume_key_service.dart';
import '../utils/constants.dart';
import '../widgets/extra_keys.dart';
import '../widgets/session_drawer.dart';
import '../widgets/task_drawer.dart';
import '../models/task.dart';
import '../utils/gesture_utils.dart';
import '../widgets/terminal_selection_handles.dart';
import '../widgets/scaled_terminal_view.dart';
import '../widgets/history_viewer.dart';
import 'settings_screen.dart';
import 'ssh_manager_screen.dart';
import 'file_manager_screen.dart';
import '../l10n/app_localizations.dart';

/// 终端主屏幕
/// 参考 termux-app: TermuxActivity.java
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _terminalFocusNode = FocusNode();
  bool _hasSelection = false;

  // 缩放相关
  double _baseScaleFontSize = 14.0;

  // 音量键修饰符状态
  bool _volumeUpModifierActive = false;
  bool _volumeDownModifierActive = false;

  // 调试信息刷新计时器
  Timer? _debugRefreshTimer;

  @override
  void initState() {
    super.initState();
    // 监听焦点变化来显示/隐藏键盘
    _terminalFocusNode.addListener(() {
      if (mounted) setState(() {});
      if (!_terminalFocusNode.hasFocus) {
        // 失去焦点时隐藏键盘
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        // 锁定焦点请求，防止滚动时误触导致键盘弹出和视图跳转
        _terminalFocusNode.canRequestFocus = false;
      }
    });

    // 初始化音量键服务
    _initVolumeKeyService();

    // 初始化终端会话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalProvider = context.read<TerminalProvider>();
      terminalProvider.init();
      // 请求焦点以启用键盘输入
      _terminalFocusNode.requestFocus();

      // 监听选择变化
      _setupSelectionListener(terminalProvider);

      // 更新音量键启用状态（只要有任一音量键配置了动作就启用）
      final settings = context.read<SettingsProvider>();
      final volumeKeysEnabled = settings.volumeUpAction != 'none' ||
          settings.volumeDownAction != 'none';
      VolumeKeyService.instance.setEnabled(volumeKeysEnabled);

      // 启动设置重载监听（支持 termux-reload-settings 命令）
      settings.startReloadWatcher();

      // 设置输入转换器
      _updateSessionInputTransformer();

      // 监听会话切换，确保新会话自动获得焦点
      terminalProvider.addListener(_onTerminalProviderChanged);

      // 登录后从远程同步 SSH 主机列表
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        context.read<SSHProvider>().syncFromApi();
        context.read<TaskProvider>().syncFromApi();
      }

      // 监听设置变化，管理调试信息刷新计时器
      settings.addListener(() => _updateDebugRefreshTimer(settings));
      _updateDebugRefreshTimer(settings);
    });
  }

  void _updateDebugRefreshTimer(SettingsProvider settings) {
    if (settings.showDebugInfo) {
      // 启动刷新计时器
      if (_debugRefreshTimer == null) {
        _debugRefreshTimer =
            Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (mounted && settings.showDebugInfo) setState(() {});
        });
      }
    } else {
      // 停止刷新计时器
      _debugRefreshTimer?.cancel();
      _debugRefreshTimer = null;
    }
  }

  void _onTerminalProviderChanged() {
    // 如果会话数量变化（通常是新建）或者索引变化（切换会话），则请求键盘
    // 这里简单地在任何变化时尝试唤醒，也可以更精细地控制
    if (mounted) {
      _updateSessionInputTransformer();
      _requestKeyboard();
    }
  }

  void _requestKeyboard() {
    if (!_terminalFocusNode.hasFocus) {
      _terminalFocusNode.canRequestFocus = true;
      _terminalFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  void _initVolumeKeyService() {
    final service = VolumeKeyService.instance;
    service.init();
    service.onVolumeKey = (key, action) {
      if (!mounted) return;

      final settings = context.read<SettingsProvider>();
      final volumeAction =
          key == 'up' ? settings.volumeUpAction : settings.volumeDownAction;

      // 如果该键被禁用，忽略
      if (volumeAction == 'none') return;

      // 检查是否为修饰键模式
      final isModifier = VolumeKeyActions.isModifier(volumeAction);

      if (isModifier) {
        // 修饰键模式：设置状态等待下一个按键
        setState(() {
          if (key == 'up') {
            _volumeUpModifierActive = action == 'down';
          } else {
            _volumeDownModifierActive = action == 'down';
          }
        });
        // 更新当前会话的输入转换器
        _updateSessionInputTransformer();
      } else if (action == 'down') {
        // 非修饰键模式：直接发送字符序列
        final sequence = VolumeKeyActions.getSequence(volumeAction);
        if (sequence.isNotEmpty) {
          _sendSequenceToTerminal(sequence);
        }
      }
    };
  }

  /// 发送字符序列到终端
  void _sendSequenceToTerminal(String sequence) {
    final terminalProvider = context.read<TerminalProvider>();
    final session = terminalProvider.currentSession;
    if (session == null) return;

    session.write(sequence);
  }

  /// 检查指定修饰符是否激活
  bool _isModifierActive(SettingsProvider settings, String modifier) {
    return (_volumeUpModifierActive && settings.volumeUpAction == modifier) ||
        (_volumeDownModifierActive && settings.volumeDownAction == modifier);
  }

  /// 检查 Ctrl 修饰符是否激活
  bool _isCtrlActive(SettingsProvider settings) =>
      _isModifierActive(settings, 'ctrl');

  /// 检查 Alt 修饰符是否激活
  bool _isAltActive(SettingsProvider settings) =>
      _isModifierActive(settings, 'alt');

  /// 切换指定修饰符
  void _toggleModifier(SettingsProvider settings, String modifier,
      {bool fallbackToVolumeUp = true}) {
    setState(() {
      if (settings.volumeUpAction == modifier) {
        _volumeUpModifierActive = !_volumeUpModifierActive;
      } else if (settings.volumeDownAction == modifier) {
        _volumeDownModifierActive = !_volumeDownModifierActive;
      } else if (fallbackToVolumeUp) {
        _volumeUpModifierActive = !_volumeUpModifierActive;
      } else {
        _volumeDownModifierActive = !_volumeDownModifierActive;
      }
    });
    _updateSessionInputTransformer();
  }

  /// 切换 Ctrl 修饰符
  void _toggleCtrlModifier(SettingsProvider settings) {
    _toggleModifier(settings, 'ctrl', fallbackToVolumeUp: true);
  }

  /// 切换 Alt 修饰符
  void _toggleAltModifier(SettingsProvider settings) {
    _toggleModifier(settings, 'alt', fallbackToVolumeUp: false);
  }

  /// 更新当前会话的输入转换器
  void _updateSessionInputTransformer() {
    final terminalProvider = context.read<TerminalProvider>();
    final session = terminalProvider.currentSession;
    if (session == null) return;

    // 设置输入转换器，用于处理 Ctrl/Alt 修饰键
    session.inputTransformer = (String input) {
      return _transformInputWithModifiers(input);
    };

    // 设置命令执行回调 - 登录后保存到后端
    session.onCommandExecuted = (String command, String sessionName) {
      final authProvider = context.read<AuthProvider>();
      if (session.isSshSession) {
        debugPrint(
            '[HistoryDiag] Skip upload for SSH session: "$command", session="$sessionName"');
        return;
      }
      debugPrint(
          '[HistoryDiag] Command captured: "$command", session="$sessionName", loggedIn=${authProvider.isLoggedIn}');
      if (authProvider.isLoggedIn) {
        ApiService.addHistory(command, sessionName: sessionName).then((ok) {
          debugPrint(
              '[HistoryDiag] Upload history result: $ok, command="$command"');
        });
      } else {
        debugPrint('[HistoryDiag] Skip upload because user is not logged in.');
      }
    };
  }

  /// 应用修饰符转换输入
  String _transformInputWithModifiers(String input) {
    // 如果没有激活任何修饰符，直接返回原始输入
    if (!_volumeUpModifierActive && !_volumeDownModifierActive) {
      return input;
    }

    final settings = context.read<SettingsProvider>();
    final volumeUpIsCtrl = settings.volumeUpAction == 'ctrl';
    final volumeUpIsAlt = settings.volumeUpAction == 'alt';
    final volumeDownIsCtrl = settings.volumeDownAction == 'ctrl';
    final volumeDownIsAlt = settings.volumeDownAction == 'alt';

    final ctrlActive = (_volumeUpModifierActive && volumeUpIsCtrl) ||
        (_volumeDownModifierActive && volumeDownIsCtrl);
    final altActive = (_volumeUpModifierActive && volumeUpIsAlt) ||
        (_volumeDownModifierActive && volumeDownIsAlt);

    final buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      var char = input.codeUnitAt(i);
      var charStr = input[i];

      // 应用 Ctrl 修饰符
      if (ctrlActive) {
        // a-z -> Ctrl+a-z (1-26)
        if (char >= 0x61 && char <= 0x7a) {
          char = char - 0x60; // 'a' -> 1, 'b' -> 2, ..., 'z' -> 26
          charStr = String.fromCharCode(char);
        }
        // A-Z -> Ctrl+A-Z (1-26)
        else if (char >= 0x41 && char <= 0x5a) {
          char = char - 0x40;
          charStr = String.fromCharCode(char);
        }
        // 特殊字符
        else if (char == 0x40 || char == 0x20) {
          // @ 或 空格 -> Ctrl+@ (NUL, 0)
          charStr = String.fromCharCode(0);
        } else if (char == 0x5b) {
          // [ -> Ctrl+[ (ESC, 27)
          charStr = String.fromCharCode(27);
        } else if (char == 0x5c) {
          // \ -> Ctrl+\ (FS, 28)
          charStr = String.fromCharCode(28);
        } else if (char == 0x5d) {
          // ] -> Ctrl+] (GS, 29)
          charStr = String.fromCharCode(29);
        } else if (char == 0x5e || char == 0x36) {
          // ^ 或 6 -> Ctrl+^ (RS, 30)
          charStr = String.fromCharCode(30);
        } else if (char == 0x5f || char == 0x2d) {
          // _ 或 - -> Ctrl+_ (US, 31)
          charStr = String.fromCharCode(31);
        }
      }

      // 应用 Alt 修饰符 (发送 ESC 前缀)
      if (altActive) {
        buffer.write('\x1b'); // ESC
      }

      buffer.write(charStr);
    }

    // 重置修饰符状态（按下一个键后自动重置）
    if (_volumeUpModifierActive || _volumeDownModifierActive) {
      // 使用 Future.microtask 避免在 build 期间调用 setState
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _volumeUpModifierActive = false;
            _volumeDownModifierActive = false;
          });
        }
      });
    }

    return buffer.toString();
  }

  void _setupSelectionListener(TerminalProvider terminalProvider) {
    // 定期检查选择状态
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return false;

      final session = terminalProvider.currentSession;
      final hasSelection = session?.controller.selection != null;

      if (hasSelection != _hasSelection) {
        setState(() {
          _hasSelection = hasSelection;
        });
      }
      return mounted;
    });
  }

  @override
  void dispose() {
    // 取消调试信息刷新计时器
    _debugRefreshTimer?.cancel();
    // 移除监听器
    context.read<TerminalProvider>().removeListener(_onTerminalProviderChanged);
    _terminalFocusNode.dispose();
    VolumeKeyService.instance.onVolumeKey = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final terminalProvider = context.watch<TerminalProvider>();
    final taskProvider = context.watch<TaskProvider>();

    // 更新屏幕常亮状态
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    // 同步音量键设置到原生层
    final volumeKeysEnabled = settings.volumeUpAction != 'none' ||
        settings.volumeDownAction != 'none';
    VolumeKeyService.instance.setEnabled(volumeKeysEnabled);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: settings.terminalTheme.background,
      appBar: _hasSelection
          ? _buildSelectionAppBar(context, terminalProvider, settings)
          : _buildAppBar(context, terminalProvider, settings),
      drawer: SessionDrawer(
        onSettingsTap: () => _openSettings(context),
      ),
      endDrawer: TaskDrawer(
        onTaskExecute: (task) => _executeTask(terminalProvider, task),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 终端视图
            Expanded(
              child: Stack(
                children: [
                  _buildTerminalView(context, terminalProvider, settings),
                  // 调试信息显示
                  if (settings.showDebugInfo)
                    Positioned(
                      top: 8,
                      right: 8,
                      child:
                          _buildDebugInfo(context, terminalProvider, settings),
                    ),
                ],
              ),
            ),
            // 额外按键（Linux桌面版默认隐藏，因为有物理键盘）
            if (settings.showExtraKeys && !Platform.isLinux)
              ExtraKeysView(
                onTextKeyTap: (key) =>
                    _sendTextKeyWithVolumeModifiers(terminalProvider, key),
                onTerminalKeyTap: (key) =>
                    _sendTerminalKey(terminalProvider, key),
                vibrationEnabled: settings.vibrationEnabled,
                ctrlPressed: _isCtrlActive(settings),
                altPressed: _isAltActive(settings),
                onCtrlToggle: () => _toggleCtrlModifier(settings),
                onAltToggle: () => _toggleAltModifier(settings),
                customCommands: taskProvider.tasks
                    .map((t) => QuickCommand(
                          label: t.name,
                          command: t.script.endsWith('\n')
                              ? t.script
                              : '${t.script}\n',
                          icon: Icons.play_arrow,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    TerminalProvider terminalProvider,
    SettingsProvider settings,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      backgroundColor: settings.terminalTheme.background,
      foregroundColor: settings.terminalTheme.foreground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _clearSelection(terminalProvider),
        tooltip: l10n.clearSelection,
      ),
      title: Text(l10n.selected),
      centerTitle: false,
      actions: [
        // 唯一的核心操作：Copy
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: () => _copySelection(terminalProvider),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.copy),
              style: FilledButton.styleFrom(
                backgroundColor:
                    settings.terminalTheme.foreground.withValues(alpha: 0.15),
                foregroundColor: settings.terminalTheme.foreground,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        // 其他所有操作收纳进菜单，保持界面极简
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.moreActions,
          itemBuilder: (context) {
            final l10n = AppLocalizations.of(context);
            return [
              PopupMenuItem(
                value: 'select_all',
                child: Row(
                  children: [
                    const Icon(Icons.select_all),
                    const SizedBox(width: 8),
                    Text(l10n.selectAll),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'copy_all',
                child: Row(
                  children: [
                    const Icon(Icons.copy_all),
                    const SizedBox(width: 8),
                    Text(l10n.copyAllOutput),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy_last_50',
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 8),
                    Text(l10n.copyLastLines),
                  ],
                ),
              ),
            ];
          },
          onSelected: (value) {
            if (value == 'select_all') {
              _selectAll(terminalProvider);
            } else if (value == 'copy_all') {
              _copyAllContent(terminalProvider);
            } else if (value == 'copy_last_50') {
              _copyLastLines(terminalProvider, 50);
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showNewSessionSheet(
      BuildContext context, TerminalProvider terminalProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final sshProvider = context.watch<SSHProvider>();
        final l10n = AppLocalizations.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.newSession,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SSHManagerScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings),
                        label: Text(l10n.manageSSH),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Local Shell Option
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.terminal),
                        ),
                        title: Text(l10n.localTerminal),
                        subtitle: Text(l10n.localTerminalDesc),
                        onTap: () {
                          Navigator.pop(context);
                          terminalProvider.createSession();
                        },
                      ),
                      if (sshProvider.hosts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            l10n.ssh,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...sshProvider.hosts.map((host) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                child: Text(host.displayName.characters.first
                                    .toUpperCase()),
                              ),
                              title: Text(host.displayName),
                              subtitle: Text('${host.username}@${host.host}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(context);
                                final shouldUploadHistory =
                                    context.read<AuthProvider>().isLoggedIn;
                                terminalProvider
                                    .createSession(
                                  title: host.displayName,
                                  isSshSession: true,
                                )
                                    .then((session) {
                                  Future.delayed(
                                      const Duration(milliseconds: 300), () {
                                    if (shouldUploadHistory) {
                                      ApiService.addHistory(
                                        host.command,
                                        sessionName: session.displayName,
                                      );
                                    }
                                    session.write('${host.command}\r');
                                  });
                                });
                              },
                            )),
                      ],
                      // Quick Connect Hint (Placeholder)
                      // ListTile(
                      //   leading: const Icon(Icons.bolt),
                      //   title: const Text('Quick Connect...'),
                      //   onTap: () { /* TODO */ },
                      // ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    TerminalProvider terminalProvider,
    SettingsProvider settings,
  ) {
    final currentSession = terminalProvider.currentSession;
    final sessionCount = terminalProvider.sessionCount;
    final l10n = AppLocalizations.of(context);

    return AppBar(
      backgroundColor: settings.terminalTheme.background.withValues(alpha: 0.9),
      foregroundColor: settings.terminalTheme.foreground,
      elevation: 0,
      leading: IconButton(
        icon: Badge(
          label: Text('$sessionCount'),
          isLabelVisible: sessionCount > 1,
          child: const Icon(Icons.menu),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: l10n.sessions,
      ),
      title: GestureDetector(
        onTap: () => _showRenameDialog(context, terminalProvider),
        child: Text(
          currentSession?.displayName ?? l10n.terminal,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      actions: [
        // 切换键盘 - 最高频操作，保留在外面
        IconButton(
          icon: Icon(_terminalFocusNode.hasFocus
              ? Icons.keyboard_hide
              : Icons.keyboard),
          onPressed: () => _toggleKeyboard(context),
          tooltip:
              _terminalFocusNode.hasFocus ? 'Hide keyboard' : 'Show keyboard',
        ),
        // 其他所有操作收纳进菜单，防止误触
        PopupMenuButton<String>(
          itemBuilder: (context) {
            final l10n = AppLocalizations.of(context);
            return [
              PopupMenuItem(
                value: 'new_session',
                child: Row(
                  children: [
                    const Icon(Icons.add),
                    const SizedBox(width: 8),
                    Text(l10n.newSession),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'tasks',
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline),
                    const SizedBox(width: 8),
                    Text(l10n.tasks),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 8),
                    Text(l10n.history),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'open_current_folder',
                child: Row(
                  children: [
                    const Icon(Icons.folder_open),
                    const SizedBox(width: 8),
                    Text(l10n.openCurrentDirectory),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'paste',
                child: Row(
                  children: [
                    const Icon(Icons.paste),
                    const SizedBox(width: 8),
                    Text(l10n.paste),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.clear_all),
                    const SizedBox(width: 8),
                    Text(l10n.clearTerminal),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'copy_ssh_key',
                child: Row(
                  children: [
                    const Icon(Icons.key),
                    const SizedBox(width: 8),
                    Text(l10n.copySSHPublicKey),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings),
                    const SizedBox(width: 8),
                    Text(l10n.settings),
                  ],
                ),
              ),
            ];
          },
          onSelected: (value) {
            if (value == 'new_session') {
              _showNewSessionSheet(context, terminalProvider);
            } else if (value == 'tasks') {
              _scaffoldKey.currentState?.openEndDrawer();
            } else {
              _handleMenuAction(context, value, terminalProvider);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTerminalView(
    BuildContext context,
    TerminalProvider terminalProvider,
    SettingsProvider settings,
  ) {
    final currentSession = terminalProvider.currentSession;
    final l10n = AppLocalizations.of(context);

    if (currentSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal,
              size: 64,
              color: settings.terminalTheme.foreground.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSessions,
              style: TextStyle(
                color: settings.terminalTheme.foreground.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => terminalProvider.createSession(),
              icon: const Icon(Icons.add),
              label: Text(l10n.createSession),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(settings.terminalMargin.toDouble()),
      // 使用 GestureDetector 处理点击唤醒键盘
      // 当键盘隐藏时（浏览模式），点击屏幕任意位置将唤醒键盘（输入模式）
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _requestKeyboard(),
        excludeFromSemantics: true,
        child: RawGestureDetector(
          gestures: {
            TwoFingerScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    TwoFingerScaleGestureRecognizer>(
              () => TwoFingerScaleGestureRecognizer(),
              (TwoFingerScaleGestureRecognizer instance) {
                instance.onStart = (details) {
                  if (details.pointerCount >= 2) {
                    _baseScaleFontSize = settings.fontSize;
                  }
                };
                instance.onUpdate = (details) {
                  if (details.pointerCount >= 2 && settings.pinchZoomEnabled) {
                    final newSize = (_baseScaleFontSize * details.scale).clamp(
                        DefaultSettings.minFontSize,
                        DefaultSettings.maxFontSize);
                    if ((newSize - settings.fontSize).abs() >= 0.5) {
                      settings.setFontSize(newSize);
                    }
                  }
                };
              },
            ),
          },
          child: Stack(
            children: [
              KeyboardListener(
                focusNode: FocusNode(),
                autofocus: false,
                onKeyEvent: (event) {
                  // 处理物理键盘的Enter键
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      currentSession.write('\r');
                    }
                  }
                },
                child: ScaledTerminalView(
                  currentSession.terminal,
                  controller: currentSession.controller,
                  scrollController: currentSession.scrollController,
                  theme: settings.terminalTheme,
                  textStyle: TerminalStyle(
                    fontFamily: _getTerminalFontFamily(settings),
                    fontSize: settings.fontSize,
                    height: 1.1,
                  ),
                  cursorType: settings.terminalCursorType,
                  alwaysShowCursor: true,
                  autofocus: true,
                  focusNode: _terminalFocusNode,
                  keyboardType: TextInputType.text,
                  onSecondaryTapDown: (details, offset) {
                    _showContextMenu(context, details, terminalProvider);
                  },
                ),
              ),
              if (_hasSelection)
                TerminalSelectionHandles(
                  terminal: currentSession.terminal,
                  controller: currentSession.controller,
                  scrollController: currentSession.scrollController,
                  textStyle: TerminalStyle(
                    fontFamily: _getTerminalFontFamily(settings),
                    fontSize: settings.fontSize,
                    height: 1.1,
                  ),
                  handleColor: settings.terminalTheme.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 发送文本键到终端
  /// 注意：ExtraKeysView 已经处理了 Ctrl/Alt 修饰键转换
  /// 这里直接写入，不再重复转换
  void _sendTextKeyWithVolumeModifiers(
      TerminalProvider terminalProvider, String key) {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    // 直接写入到 shell（绕过 inputTransformer，因为 ExtraKeysView 已经处理了转换）
    session.write(key);
  }

  void _sendTerminalKey(TerminalProvider terminalProvider, TerminalKey key) {
    final session = terminalProvider.currentSession;
    if (session != null) {
      // 直接调用xterm的keyInput方法来处理特殊按键
      session.terminal.keyInput(key);
    }
  }

  void _toggleKeyboard(BuildContext context) {
    // 在Android上使用FocusNode来切换键盘
    if (_terminalFocusNode.hasFocus) {
      // 如果已有焦点，失去焦点以隐藏键盘
      _terminalFocusNode.unfocus();
      // 这里的 canRequestFocus = false 会在 listener 中设置
    } else {
      // 解锁并请求焦点以显示键盘
      _terminalFocusNode.canRequestFocus = true;
      _terminalFocusNode.requestFocus();
    }
  }

  /// 获取终端字体族名称
  /// 支持：自定义字体 > 内置 Nerd Font > Google Fonts
  String _getTerminalFontFamily(SettingsProvider settings) {
    // 使用内置字体（自定义字体或 Nerd Font）
    if (settings.useBuiltInFont) {
      return settings.effectiveFontFamily;
    }
    // 使用 Google Fonts
    try {
      return GoogleFonts.getFont(settings.fontFamily).fontFamily ?? 'monospace';
    } catch (e) {
      // 如果 Google Fonts 加载失败，回退到内置 Nerd Font
      return AvailableFonts.nerdFontFamily;
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showHistoryViewer(
      BuildContext context, TerminalProvider terminalProvider) {
    HistoryViewer.show(
      context,
      onCommandSelected: (command) {
        // 将命令发送到终端
        final session = terminalProvider.currentSession;
        if (session != null) {
          session.write('$command\n');
        }
      },
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    TerminalProvider terminalProvider,
  ) {
    switch (action) {
      case 'copy':
        _copySelection(terminalProvider);
        break;
      case 'copy_last_50':
        _copyLastLines(terminalProvider, 50);
        break;
      case 'copy_all':
        _copyAllContent(terminalProvider);
        break;
      case 'paste':
        _pasteClipboard(terminalProvider);
        break;
      case 'settings':
        _openSettings(context);
        break;
      case 'history':
        _showHistoryViewer(context, terminalProvider);
        break;
      case 'open_current_folder':
        _openCurrentFolderInFileManager(terminalProvider);
        break;
      case 'copy_ssh_key':
        _copySshPublicKey();
        break;
      case 'clear':
        _clearTerminal(terminalProvider);
        break;
    }
  }

  Future<void> _openCurrentFolderInFileManager(
    TerminalProvider terminalProvider,
  ) async {
    final session = terminalProvider.currentSession;
    final initialPath = await session?.queryCurrentWorkingDirectory() ??
        TermuxConstants.homeDir;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileManagerScreen(initialPath: initialPath),
      ),
    );
  }

  /// 复制最后N行终端内容
  void _copyLastLines(TerminalProvider terminalProvider, int lineCount) async {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    final terminal = session.terminal;
    final buffer = terminal.buffer;

    // 获取所有行的文本
    final allLines = <String>[];
    for (int i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final text = line.getText().trimRight();
      allLines.add(text);
    }

    // 移除末尾的空行
    while (allLines.isNotEmpty && allLines.last.isEmpty) {
      allLines.removeLast();
    }

    if (allLines.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terminal is empty'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // 取最后N行
    final startIndex = (allLines.length - lineCount).clamp(0, allLines.length);
    final lastLines = allLines.sublist(startIndex);
    final text = lastLines.join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${lastLines.length} lines to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 复制所有终端内容
  void _copyAllContent(TerminalProvider terminalProvider) async {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    final terminal = session.terminal;
    final buffer = terminal.buffer;

    // 获取所有行的文本
    final lines = <String>[];
    for (int i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final text = line.getText().trimRight();
      lines.add(text);
    }

    // 移除末尾的空行
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    final text = lines.join('\n');

    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied ${lines.length} lines to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terminal is empty'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _copySelection(TerminalProvider terminalProvider) async {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    final selection = session.controller.selection;
    if (selection != null) {
      final text = session.terminal.buffer.getText(selection);
      await Clipboard.setData(ClipboardData(text: text));

      // Clear selection after copying
      session.controller.clearSelection();
      setState(() {
        _hasSelection = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _pasteClipboard(TerminalProvider terminalProvider) async {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      // 发送到shell进程，而不是直接写到终端显示
      session.write(data!.text!);
    }
  }

  /// 执行任务脚本
  void _executeTask(TerminalProvider terminalProvider, Task task) {
    final session = terminalProvider.currentSession;
    if (session == null) {
      // 如果没有会话，先创建一个
      terminalProvider.createSession();
      // 等待会话创建完成后执行
      Future.delayed(const Duration(milliseconds: 100), () {
        final newSession = terminalProvider.currentSession;
        if (newSession != null) {
          _sendTaskScript(newSession, task);
        }
      });
    } else {
      _sendTaskScript(session, task);
    }
  }

  /// 发送任务脚本到终端
  void _sendTaskScript(dynamic session, Task task) {
    // 发送脚本到shell
    // 如果脚本不以换行结尾，添加换行以执行
    var script = task.script;
    if (!script.endsWith('\n')) {
      script += '\n';
    }
    session.write(script);
  }

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    TerminalProvider terminalProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 20),
              const SizedBox(width: 8),
              Text(l10n.copy),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              const Icon(Icons.paste, size: 20),
              const SizedBox(width: 8),
              Text(l10n.paste),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              const Icon(Icons.clear_all, size: 20),
              const SizedBox(width: 8),
              Text(l10n.clearTerminal),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        _copySelection(terminalProvider);
      } else if (value == 'paste') {
        _pasteClipboard(terminalProvider);
      } else if (value == 'clear') {
        _clearTerminal(terminalProvider);
      }
    });
  }

  void _selectAll(TerminalProvider terminalProvider) {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    // Select all visible content in the terminal buffer
    final terminal = session.terminal;
    final buffer = terminal.buffer;

    // Create anchors from cell offsets
    const beginOffset = CellOffset(0, 0);
    final endOffset = CellOffset(terminal.viewWidth - 1, buffer.height - 1);

    // 我们的本地 CellAnchor 与 xterm 的 CellAnchor 具有相同的 API
    final beginAnchor = buffer.createAnchorFromOffset(beginOffset);
    final endAnchor = buffer.createAnchorFromOffset(endOffset);
    session.controller.setSelection(
      beginAnchor,
      endAnchor,
    );
  }

  /// 清除当前终端
  void _clearTerminal(TerminalProvider terminalProvider) {
    terminalProvider.clearCurrentTerminal();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.terminalCleared),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 复制 SSH 公钥到剪贴板
  Future<void> _copySshPublicKey() async {
    final sshDir = '${TermuxConstants.homeDir}/.ssh';
    final keyFiles = [
      'id_ed25519.pub',
      'id_rsa.pub',
      'id_ecdsa.pub',
      'id_dsa.pub',
    ];

    for (final keyFile in keyFiles) {
      final file = File('$sshDir/$keyFile');
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          await Clipboard.setData(ClipboardData(text: content.trim()));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $keyFile to clipboard'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to read $keyFile: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    }

    // 没有找到任何公钥文件
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No SSH public key found. Run: ssh-keygen'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Generate',
            onPressed: () {
              final terminalProvider = context.read<TerminalProvider>();
              final session = terminalProvider.currentSession;
              if (session != null) {
                session.write('ssh-keygen -t ed25519\n');
              }
            },
          ),
        ),
      );
    }
  }

  void _clearSelection(TerminalProvider terminalProvider) {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    session.controller.clearSelection();
    setState(() {
      _hasSelection = false;
    });
  }

  /// 构建调试信息显示
  Widget _buildDebugInfo(
    BuildContext context,
    TerminalProvider terminalProvider,
    SettingsProvider settings,
  ) {
    final session = terminalProvider.currentSession;
    if (session == null) return const SizedBox.shrink();

    final terminal = session.terminal;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG INFO',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terminal: ${terminal.viewWidth}x${terminal.viewHeight}',
            style: const TextStyle(
                color: Colors.yellow,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          Text(
            'Shell: ${session.lastShellColumns ?? "?"}x${session.lastShellRows ?? "?"}',
            style: const TextStyle(
                color: Colors.lightGreen,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          Text(
            'Buffer lines: ${terminal.buffer.lines.length}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'Cursor: (${terminal.buffer.cursorX}, ${terminal.buffer.cursorY})',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'AbsCursorY: ${terminal.buffer.absoluteCursorY}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'AltBuffer: ${terminal.isUsingAltBuffer}',
            style: TextStyle(
              color: terminal.isUsingAltBuffer ? Colors.orange : Colors.white,
              fontSize: 10,
            ),
          ),
          const Divider(height: 8, color: Colors.grey),
          Text(
            'FontSize: ${settings.fontSize.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'Margin: ${settings.terminalMargin}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'Screen: ${mediaQuery.size.width.toInt()}x${mediaQuery.size.height.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            'ViewInsets.bottom: ${mediaQuery.viewInsets.bottom.toInt()}',
            style: const TextStyle(color: Colors.cyan, fontSize: 10),
          ),
          Text(
            'Padding: T${mediaQuery.padding.top.toInt()} B${mediaQuery.padding.bottom.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    TerminalProvider terminalProvider,
  ) {
    final currentSession = terminalProvider.currentSession;
    if (currentSession == null) return;

    final controller = TextEditingController(text: currentSession.title);
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameSession),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.sessions,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              terminalProvider.renameCurrentSession(value);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                terminalProvider.renameCurrentSession(controller.text);
              }
              Navigator.pop(context);
            },
            child: Text(l10n.rename),
          ),
        ],
      ),
    );
  }
}
