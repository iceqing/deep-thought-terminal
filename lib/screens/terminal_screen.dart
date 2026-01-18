import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/volume_key_service.dart';
import '../utils/constants.dart';
import '../widgets/extra_keys.dart';
import '../widgets/session_drawer.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // 监听焦点变化来显示/隐藏键盘
    _terminalFocusNode.addListener(() {
      if (!_terminalFocusNode.hasFocus) {
        // 失去焦点时隐藏键盘
        SystemChannels.textInput.invokeMethod('TextInput.hide');
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

      // 设置输入转换器
      _updateSessionInputTransformer();
    });
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
    _terminalFocusNode.dispose();
    VolumeKeyService.instance.onVolumeKey = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final terminalProvider = context.watch<TerminalProvider>();

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
      appBar: _buildAppBar(context, terminalProvider, settings),
      drawer: SessionDrawer(
        onSettingsTap: () => _openSettings(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 终端视图
            Expanded(
              child: Stack(
                children: [
                  _buildTerminalView(context, terminalProvider, settings),
                  // 选中文字时显示的浮动操作栏
                  if (_hasSelection)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: _buildSelectionToolbar(context, terminalProvider, settings),
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
              ),
          ],
        ),
      ),
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
        // 快速复制按钮
        IconButton(
          icon: const Icon(Icons.copy_all),
          onPressed: () => _showCopyOptions(context, terminalProvider),
          tooltip: 'Copy options',
        ),
        // 切换键盘
        IconButton(
          icon: const Icon(Icons.keyboard),
          onPressed: () => _toggleKeyboard(context),
          tooltip: 'Toggle keyboard',
        ),
        // 新建会话
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => terminalProvider.createSession(),
          tooltip: 'New session',
        ),
        // 更多选项
        PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('Copy Selection'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy_all',
              child: Row(
                children: [
                  Icon(Icons.copy_all),
                  SizedBox(width: 8),
                  Text('Copy All'),
                ],
              ),
            ),
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
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
          onSelected: (value) =>
              _handleMenuAction(context, value, terminalProvider),
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
      child: GestureDetector(
        // 双指缩放调整字体大小
        onScaleStart: (details) {
          if (details.pointerCount >= 2) {
            _baseScaleFontSize = settings.fontSize;
          }
        },
        onScaleUpdate: (details) {
          if (details.pointerCount >= 2 && settings.pinchZoomEnabled) {
            // 计算新的字体大小
            final newSize = (_baseScaleFontSize * details.scale)
                .clamp(DefaultSettings.minFontSize, DefaultSettings.maxFontSize);
            // 只有当变化超过0.5时才更新，避免频繁刷新
            if ((newSize - settings.fontSize).abs() >= 0.5) {
              settings.setFontSize(newSize);
            }
          }
        },
        child: KeyboardListener(
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
          child: TerminalView(
            currentSession.terminal,
            controller: currentSession.controller,
            theme: settings.terminalTheme,
            textStyle: TerminalStyle(
              fontFamily: GoogleFonts.getFont(settings.fontFamily).fontFamily ??
                  'monospace',
              fontSize: settings.fontSize,
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
    } else {
      // 请求焦点以显示键盘
      _terminalFocusNode.requestFocus();
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
      case 'copy_all':
        _copyAllContent(terminalProvider);
        break;
      case 'paste':
        _pasteClipboard(terminalProvider);
        break;
      case 'select_all':
        _selectAll(terminalProvider);
        break;
      case 'settings':
        _openSettings(context);
        break;
    }
  }

  /// 显示复制选项弹窗
  void _showCopyOptions(BuildContext context, TerminalProvider terminalProvider) {
    final settings = context.read<SettingsProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: settings.terminalTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: settings.terminalTheme.foreground.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Copy Options',
                style: TextStyle(
                  color: settings.terminalTheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildCopyOptionTile(
                icon: Icons.copy_all,
                title: 'Copy All Content',
                subtitle: 'Copy entire terminal buffer',
                onTap: () {
                  Navigator.pop(context);
                  _copyAllContent(terminalProvider);
                },
                settings: settings,
              ),
              _buildCopyOptionTile(
                icon: Icons.select_all,
                title: 'Select All & Copy',
                subtitle: 'Select all text and copy',
                onTap: () {
                  Navigator.pop(context);
                  _selectAll(terminalProvider);
                  // 延迟一下让选择生效后再复制
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _copySelection(terminalProvider);
                  });
                },
                settings: settings,
              ),
              if (_hasSelection)
                _buildCopyOptionTile(
                  icon: Icons.copy,
                  title: 'Copy Selection',
                  subtitle: 'Copy currently selected text',
                  onTap: () {
                    Navigator.pop(context);
                    _copySelection(terminalProvider);
                  },
                  settings: settings,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required SettingsProvider settings,
  }) {
    return ListTile(
      leading: Icon(icon, color: settings.terminalTheme.foreground),
      title: Text(
        title,
        style: TextStyle(color: settings.terminalTheme.foreground),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: settings.terminalTheme.foreground.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
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

  Widget _buildSelectionToolbar(
    BuildContext context,
    TerminalProvider terminalProvider,
    SettingsProvider settings,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: settings.terminalTheme.background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: settings.terminalTheme.foreground.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制选中内容 - 主要按钮
            _buildToolbarPrimaryButton(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () => _copySelection(terminalProvider),
              settings: settings,
            ),
            _buildToolbarDivider(settings),
            // 复制全部
            _buildToolbarButton(
              icon: Icons.copy_all,
              label: 'All',
              onTap: () => _copyAllContent(terminalProvider),
              settings: settings,
            ),
            _buildToolbarDivider(settings),
            // 全选
            _buildToolbarButton(
              icon: Icons.select_all,
              label: 'Select All',
              onTap: () => _selectAll(terminalProvider),
              settings: settings,
            ),
            _buildToolbarDivider(settings),
            // 清除选择
            _buildToolbarButton(
              icon: Icons.close,
              label: '',
              onTap: () => _clearSelection(terminalProvider),
              settings: settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required SettingsProvider settings,
  }) {
    return Material(
      color: settings.terminalTheme.foreground.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: settings.terminalTheme.foreground,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: settings.terminalTheme.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required SettingsProvider settings,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: settings.terminalTheme.foreground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: settings.terminalTheme.foreground,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarDivider(SettingsProvider settings) {
    return Container(
      width: 1,
      height: 20,
      color: settings.terminalTheme.foreground.withOpacity(0.2),
    );
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

    session.controller.setSelection(
      buffer.createAnchorFromOffset(beginOffset),
      buffer.createAnchorFromOffset(endOffset),
    );
  }

  void _clearSelection(TerminalProvider terminalProvider) {
    final session = terminalProvider.currentSession;
    if (session == null) return;

    session.controller.clearSelection();
    setState(() {
      _hasSelection = false;
    });
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
