import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

/// 额外按键组件
/// 参考 termux-app: ExtraKeysView.java, ExtraKeyButton.java

/// 按键定义
class ExtraKey {
  final String label;
  final String? displayLabel;
  final String? text;  // 普通文本字符
  final TerminalKey? terminalKey;  // xterm特殊按键
  final bool isModifier;
  final IconData? icon;

  const ExtraKey({
    required this.label,
    this.displayLabel,
    this.text,
    this.terminalKey,
    this.isModifier = false,
    this.icon,
  });

  String get display => displayLabel ?? label;
}

/// 预定义的额外按键
class ExtraKeys {
  // ESC键
  static const esc = ExtraKey(label: 'ESC', terminalKey: TerminalKey.escape);

  // TAB键
  static const tab = ExtraKey(label: 'TAB', terminalKey: TerminalKey.tab);

  // CTRL修饰键
  static const ctrl = ExtraKey(label: 'CTRL', isModifier: true);

  // ALT修饰键
  static const alt = ExtraKey(label: 'ALT', isModifier: true);

  // HOME键
  static const home = ExtraKey(label: 'HOME', terminalKey: TerminalKey.home);

  // END键
  static const end = ExtraKey(label: 'END', terminalKey: TerminalKey.end);

  // PAGE UP键
  static const pgup = ExtraKey(label: 'PGUP', displayLabel: '↑PG', terminalKey: TerminalKey.pageUp);

  // PAGE DOWN键
  static const pgdn = ExtraKey(label: 'PGDN', displayLabel: '↓PG', terminalKey: TerminalKey.pageDown);

  // 方向键
  static const up = ExtraKey(label: 'UP', terminalKey: TerminalKey.arrowUp, icon: Icons.keyboard_arrow_up);
  static const down = ExtraKey(label: 'DOWN', terminalKey: TerminalKey.arrowDown, icon: Icons.keyboard_arrow_down);
  static const left = ExtraKey(label: 'LEFT', terminalKey: TerminalKey.arrowLeft, icon: Icons.keyboard_arrow_left);
  static const right = ExtraKey(label: 'RIGHT', terminalKey: TerminalKey.arrowRight, icon: Icons.keyboard_arrow_right);

  // 回车键
  static const enter = ExtraKey(label: 'ENTER', displayLabel: '↲', terminalKey: TerminalKey.enter);

  // 退格键
  static const backspace = ExtraKey(label: 'DEL', displayLabel: '⌫', terminalKey: TerminalKey.backspace);

  // 删除键 (向前删除)
  static const deleteKey = ExtraKey(label: 'FORWARD_DEL', displayLabel: '⌦', terminalKey: TerminalKey.delete);

  static const dash = ExtraKey(label: '-', text: '-');
  static const slash = ExtraKey(label: '/', text: '/');
  static const pipe = ExtraKey(label: '|', text: '|');
  static const backslash = ExtraKey(label: '\\', text: '\\');
  static const underscore = ExtraKey(label: '_', text: '_');

  /// 默认按键行布局（两行）
  static const List<List<ExtraKey>> defaultLayout = [
    [esc, tab, ctrl, alt, dash, underscore, up, slash],
    [home, end, pgup, pgdn, left, down, right, pipe],
  ];

  /// 简单按键行布局（单行）
  static const List<ExtraKey> simpleLayout = [
    esc,
    tab,
    ctrl,
    alt,
    left,
    backspace,
    enter,
    up,
    down,
    right,
  ];
}

/// 额外按键视图
class ExtraKeysView extends StatefulWidget {
  final Function(String) onTextKeyTap;  // 普通文本按键
  final Function(TerminalKey) onTerminalKeyTap;  // xterm特殊按键
  final VoidCallback? onCtrlToggle;
  final VoidCallback? onAltToggle;
  final bool vibrationEnabled;

  const ExtraKeysView({
    super.key,
    required this.onTextKeyTap,
    required this.onTerminalKeyTap,
    this.onCtrlToggle,
    this.onAltToggle,
    this.vibrationEnabled = true,
  });

  @override
  State<ExtraKeysView> createState() => _ExtraKeysViewState();
}

class _ExtraKeysViewState extends State<ExtraKeysView> {
  bool _ctrlPressed = false;
  bool _altPressed = false;

  void _handleKeyTap(ExtraKey key) {
    if (widget.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    if (key.isModifier) {
      if (key.label == 'CTRL') {
        setState(() => _ctrlPressed = !_ctrlPressed);
        widget.onCtrlToggle?.call();
      } else if (key.label == 'ALT') {
        setState(() => _altPressed = !_altPressed);
        widget.onAltToggle?.call();
      }
    } else if (key.terminalKey != null) {
      // 使用xterm的特殊按键处理
      widget.onTerminalKeyTap(key.terminalKey!);
      setState(() {
        _ctrlPressed = false;
        _altPressed = false;
      });
    } else if (key.text != null) {
      // 普通文本按键
      String keyToSend = key.text!;

      // 处理 Ctrl 组合键
      if (_ctrlPressed) {
        final char = keyToSend.codeUnitAt(0);
        if (char >= 0x61 && char <= 0x7a) {
          keyToSend = String.fromCharCode(char - 0x60);
        } else if (char >= 0x41 && char <= 0x5a) {
          keyToSend = String.fromCharCode(char - 0x40);
        }
        setState(() => _ctrlPressed = false);
      }

      // 处理 Alt 组合键
      if (_altPressed) {
        keyToSend = '\x1b$keyToSend';
        setState(() => _altPressed = false);
      }

      widget.onTextKeyTap(keyToSend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeyRow(ExtraKeys.simpleLayout, theme),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<ExtraKey> keys, ThemeData theme) {
    return SizedBox(
      height: 42,
      child: Row(
        children: keys.map((key) => _buildKey(key, theme)).toList(),
      ),
    );
  }

  Widget _buildKey(ExtraKey key, ThemeData theme) {
    final isPressed = (key.label == 'CTRL' && _ctrlPressed) ||
        (key.label == 'ALT' && _altPressed);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isPressed
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () => _handleKeyTap(key),
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: key.icon != null
                  ? Icon(
                      key.icon,
                      size: 20,
                      color: isPressed
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    )
                  : Text(
                      key.display,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isPressed
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 完整的额外按键视图（两行）
class FullExtraKeysView extends StatefulWidget {
  final Function(String) onTextKeyTap;
  final Function(TerminalKey) onTerminalKeyTap;
  final bool vibrationEnabled;

  const FullExtraKeysView({
    super.key,
    required this.onTextKeyTap,
    required this.onTerminalKeyTap,
    this.vibrationEnabled = true,
  });

  @override
  State<FullExtraKeysView> createState() => _FullExtraKeysViewState();
}

class _FullExtraKeysViewState extends State<FullExtraKeysView> {
  bool _ctrlPressed = false;
  bool _altPressed = false;

  void _handleKeyTap(ExtraKey key) {
    if (widget.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    if (key.isModifier) {
      if (key.label == 'CTRL') {
        setState(() => _ctrlPressed = !_ctrlPressed);
      } else if (key.label == 'ALT') {
        setState(() => _altPressed = !_altPressed);
      }
    } else if (key.terminalKey != null) {
      widget.onTerminalKeyTap(key.terminalKey!);
      setState(() {
        _ctrlPressed = false;
        _altPressed = false;
      });
    } else if (key.text != null) {
      String keyToSend = key.text!;

      if (_ctrlPressed) {
        final char = keyToSend.codeUnitAt(0);
        if (char >= 0x61 && char <= 0x7a) {
          keyToSend = String.fromCharCode(char - 0x60);
        } else if (char >= 0x41 && char <= 0x5a) {
          keyToSend = String.fromCharCode(char - 0x40);
        }
        setState(() => _ctrlPressed = false);
      }

      if (_altPressed) {
        keyToSend = '\x1b$keyToSend';
        setState(() => _altPressed = false);
      }

      widget.onTextKeyTap(keyToSend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ExtraKeys.defaultLayout
            .map((row) => _buildKeyRow(row, theme))
            .toList(),
      ),
    );
  }

  Widget _buildKeyRow(List<ExtraKey> keys, ThemeData theme) {
    return SizedBox(
      height: 42,
      child: Row(
        children: keys.map((key) => _buildKey(key, theme)).toList(),
      ),
    );
  }

  Widget _buildKey(ExtraKey key, ThemeData theme) {
    final isPressed = (key.label == 'CTRL' && _ctrlPressed) ||
        (key.label == 'ALT' && _altPressed);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isPressed
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () => _handleKeyTap(key),
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: key.icon != null
                  ? Icon(
                      key.icon,
                      size: 20,
                      color: isPressed
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    )
                  : Text(
                      key.display,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isPressed
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
