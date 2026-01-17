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
              child: _buildTerminalView(context, terminalProvider, settings),
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
        keyboardType: TextInputType.text,
        onSecondaryTapDown: (details, offset) {
          _showContextMenu(context, details, terminalProvider);
        },
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
