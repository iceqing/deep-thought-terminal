import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/task_provider.dart';
import '../services/volume_key_service.dart';
import '../utils/constants.dart';
import '../widgets/extra_keys.dart';
import '../widgets/session_drawer.dart';
import '../widgets/task_drawer.dart';
import '../models/task.dart';
import '../utils/gesture_utils.dart';
import '../widgets/terminal_selection_handles.dart';
import '../widgets/scaled_terminal_view.dart';
import 'settings_screen.dart';
import 'ssh_manager_screen.dart';

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
  bool _volumeUpCtrlActive = false;
  bool _volumeDownAltActive = false;

  // 调试信息刷新计时器
  Timer? _debugRefreshTimer;

  // 是否显示调试信息
  bool _showDebugInfo = false;

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

      // 更新音量键启用状态
      final settings = context.read<SettingsProvider>();
      VolumeKeyService.instance.setEnabled(settings.volumeKeysEnabled);

      // 启动设置重载监听（支持 termux-reload-settings 命令）
      settings.startReloadWatcher();

      // 设置输入转换器
      _updateSessionInputTransformer();

      // 监听会话切换，确保新会话自动获得焦点
      terminalProvider.addListener(_onTerminalProviderChanged);
    });

    // 调试信息刷新计时器在需要时启动
  }

  void _toggleDebugInfo() {
    setState(() {
      _showDebugInfo = !_showDebugInfo;
      if (_showDebugInfo) {
        // 启动刷新计时器
        _debugRefreshTimer?.cancel();
        _debugRefreshTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (mounted && _showDebugInfo) setState(() {});
        });
      } else {
        // 停止刷新计时器
        _debugRefreshTimer?.cancel();
        _debugRefreshTimer = null;
      }
    });
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
      if (!settings.volumeKeysEnabled) return;

      setState(() {
        if (key == 'up') {
          // 音量上键 = Ctrl
          _volumeUpCtrlActive = action == 'down';
        } else if (key == 'down') {
          // 音量下键 = Alt
          _volumeDownAltActive = action == 'down';
        }
      });

      // 更新当前会话的输入转换器
      _updateSessionInputTransformer();
    };
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
  }

  /// 应用修饰符转换输入
  String _transformInputWithModifiers(String input) {
    // 如果没有激活任何修饰符，直接返回原始输入
    if (!_volumeUpCtrlActive && !_volumeDownAltActive) {
      return input;
    }

    final buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      var char = input.codeUnitAt(i);
      var charStr = input[i];

      // 应用 Ctrl 修饰符
      if (_volumeUpCtrlActive) {
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
      if (_volumeDownAltActive) {
        buffer.write('\x1b'); // ESC
      }

      buffer.write(charStr);
    }

    // 重置修饰符状态（按下一个键后自动重置）
    if (_volumeUpCtrlActive || _volumeDownAltActive) {
      // 使用 Future.microtask 避免在 build 期间调用 setState
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _volumeUpCtrlActive = false;
            _volumeDownAltActive = false;
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
    VolumeKeyService.instance.setEnabled(settings.volumeKeysEnabled);

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
                  if (_showDebugInfo)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildDebugInfo(context, terminalProvider, settings),
                    ),
                ],
              ),
            ),
            // 额外按键
            if (settings.showExtraKeys)
              ExtraKeysView(
                onTextKeyTap: (key) => _sendTextKeyWithVolumeModifiers(terminalProvider, key),
                onTerminalKeyTap: (key) =>
                    _sendTerminalKey(terminalProvider, key),
                vibrationEnabled: settings.vibrationEnabled,
                ctrlPressed: _volumeUpCtrlActive,
                altPressed: _volumeDownAltActive,
                onCtrlToggle: () => setState(() => _volumeUpCtrlActive = !_volumeUpCtrlActive),
                onAltToggle: () => setState(() => _volumeDownAltActive = !_volumeDownAltActive),
                customCommands: taskProvider.tasks.map((t) => QuickCommand(
                  label: t.name,
                  command: t.script.endsWith('\n') ? t.script : '${t.script}\n',
                  icon: Icons.play_arrow,
                )).toList(),
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
    return AppBar(
      backgroundColor: settings.terminalTheme.background,
      foregroundColor: settings.terminalTheme.foreground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _clearSelection(terminalProvider),
        tooltip: 'Clear selection',
      ),
      title: const Text('Selected'),
      centerTitle: false,
      actions: [
        // 唯一的核心操作：Copy
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: () => _copySelection(terminalProvider),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
              style: FilledButton.styleFrom(
                backgroundColor: settings.terminalTheme.foreground.withOpacity(0.15),
                foregroundColor: settings.terminalTheme.foreground,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        // 其他所有操作收纳进菜单，保持界面极简
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More actions',
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'select_all',
              child: Row(
                children: [
                  Icon(Icons.select_all),
                  SizedBox(width: 8),
                  Text('Select All'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'copy_all',
              child: Row(
                children: [
                  Icon(Icons.copy_all),
                  SizedBox(width: 8),
                  Text('Copy All Output'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy_last_50',
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('Copy Last 50 Lines'),
                ],
              ),
            ),
          ],
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

  void _showNewSessionSheet(BuildContext context, TerminalProvider terminalProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final sshProvider = context.watch<SSHProvider>();
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
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'New Session',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SSHManagerScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Manage SSH'),
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
                        title: const Text('Local Terminal'),
                        subtitle: const Text('Start a new local shell session'),
                        onTap: () {
                          Navigator.pop(context);
                          terminalProvider.createSession();
                        },
                      ),
                      if (sshProvider.hosts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'SSH Connections',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...sshProvider.hosts.map((host) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                child: Text(host.displayName.characters.first.toUpperCase()),
                              ),
                              title: Text(host.displayName),
                              subtitle: Text('${host.username}@${host.host}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(context);
                                terminalProvider.createSession(title: host.displayName).then((session) {
                                  Future.delayed(const Duration(milliseconds: 300), () {
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

    return AppBar(
      backgroundColor: settings.terminalTheme.background.withOpacity(0.9),
      foregroundColor: settings.terminalTheme.foreground,
      elevation: 0,
      leading: IconButton(
        icon: Badge(
          label: Text('$sessionCount'),
          isLabelVisible: sessionCount > 1,
          child: const Icon(Icons.menu),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: 'Sessions',
      ),
      title: GestureDetector(
        onTap: () => _showRenameDialog(context, terminalProvider),
        child: Text(
          currentSession?.displayName ?? 'Terminal',
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
          tooltip: _terminalFocusNode.hasFocus ? 'Hide keyboard' : 'Show keyboard',
        ),
        // 其他所有操作收纳进菜单，防止误触
        PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'new_session',
              child: Row(
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('New Session'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'tasks',
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline),
                  SizedBox(width: 8),
                  Text('Tasks'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'paste',
              child: Row(
                children: [
                  Icon(Icons.paste),
                  SizedBox(width: 8),
                  Text('Paste'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'debug',
              child: Row(
                children: [
                  Icon(_showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined),
                  const SizedBox(width: 8),
                  Text(_showDebugInfo ? 'Hide Debug Info' : 'Show Debug Info'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'copy_ssh_key',
              child: Row(
                children: [
                  Icon(Icons.key),
                  SizedBox(width: 8),
                  Text('Copy SSH Public Key'),
                ],
              ),
            ),
          ],
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

    if (currentSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal,
              size: 64,
              color: settings.terminalTheme.foreground.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No active session',
              style: TextStyle(
                color: settings.terminalTheme.foreground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => terminalProvider.createSession(),
              icon: const Icon(Icons.add),
              label: const Text('Create Session'),
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
          TwoFingerScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
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
                  final newSize = (_baseScaleFontSize * details.scale)
                      .clamp(DefaultSettings.minFontSize, DefaultSettings.maxFontSize);
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
            // 使用visiblePassword明确告诉系统这不是密码输入
            // 这可以避免触发小米等厂商的安全键盘
            keyboardType: TextInputType.visiblePassword,
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
  void _sendTextKeyWithVolumeModifiers(TerminalProvider terminalProvider, String key) {
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
      case 'debug':
        _toggleDebugInfo();
        break;
      case 'copy_ssh_key':
        _copySshPublicKey();
        break;
    }
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
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.paste, size: 20),
              SizedBox(width: 8),
              Text('Paste'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        _copySelection(terminalProvider);
      } else if (value == 'paste') {
        _pasteClipboard(terminalProvider);
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
        color: Colors.black.withOpacity(0.7),
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
            style: const TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Text(
            'Shell: ${session.lastShellColumns ?? "?"}x${session.lastShellRows ?? "?"}',
            style: const TextStyle(color: Colors.lightGreen, fontSize: 10, fontWeight: FontWeight.bold),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session name',
            border: OutlineInputBorder(),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                terminalProvider.renameCurrentSession(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
