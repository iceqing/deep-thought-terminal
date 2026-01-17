import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
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
    // 初始化终端会话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalProvider = context.read<TerminalProvider>();
      terminalProvider.init();
      // 请求焦点以启用键盘输入
      _terminalFocusNode.requestFocus();

      // 监听选择变化
      _setupSelectionListener(terminalProvider);
    });
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
                onTextKeyTap: (key) => _sendTextKey(terminalProvider, key),
                onTerminalKeyTap: (key) =>
                    _sendTerminalKey(terminalProvider, key),
                vibrationEnabled: settings.vibrationEnabled,
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
                  Text('Copy'),
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
    );
  }

  void _sendTextKey(TerminalProvider terminalProvider, String key) {
    final session = terminalProvider.currentSession;
    if (session != null) {
      session.write(key);
    }
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
      case 'paste':
        _pasteClipboard(terminalProvider);
        break;
      case 'settings':
        _openSettings(context);
        break;
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
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: settings.terminalTheme.background.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: settings.terminalTheme.foreground.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () => _copySelection(terminalProvider),
              settings: settings,
            ),
            _buildToolbarDivider(settings),
            _buildToolbarButton(
              icon: Icons.select_all,
              label: 'Select All',
              onTap: () => _selectAll(terminalProvider),
              settings: settings,
            ),
            _buildToolbarDivider(settings),
            _buildToolbarButton(
              icon: Icons.clear,
              label: 'Clear',
              onTap: () => _clearSelection(terminalProvider),
              settings: settings,
            ),
          ],
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
