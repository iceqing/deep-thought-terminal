import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 额外按键组件
/// 参考 termux-app: ExtraKeysView.java, ExtraKeyButton.java

/// 按键定义
class ExtraKey {
  final String label;
  final String? displayLabel;
  final String? key;
  final bool isModifier;
  final IconData? icon;

  const ExtraKey({
    required this.label,
    this.displayLabel,
    this.key,
    this.isModifier = false,
    this.icon,
  });

  String get display => displayLabel ?? label;
}

/// 预定义的额外按键
class ExtraKeys {
  static const esc = ExtraKey(label: 'ESC', key: '\x1b');
  static const tab = ExtraKey(label: 'TAB', key: '\t');
  static const ctrl = ExtraKey(label: 'CTRL', isModifier: true);
  static const alt = ExtraKey(label: 'ALT', isModifier: true);
  static const home = ExtraKey(label: 'HOME', key: '\x1b[H');
  static const end = ExtraKey(label: 'END', key: '\x1b[F');
  static const pgup = ExtraKey(label: 'PGUP', displayLabel: '↑PG', key: '\x1b[5~');
  static const pgdn = ExtraKey(label: 'PGDN', displayLabel: '↓PG', key: '\x1b[6~');

  static const up = ExtraKey(label: 'UP', key: '\x1b[A', icon: Icons.keyboard_arrow_up);
  static const down = ExtraKey(label: 'DOWN', key: '\x1b[B', icon: Icons.keyboard_arrow_down);
  static const left = ExtraKey(label: 'LEFT', key: '\x1b[D', icon: Icons.keyboard_arrow_left);
  static const right = ExtraKey(label: 'RIGHT', key: '\x1b[C', icon: Icons.keyboard_arrow_right);

  static const dash = ExtraKey(label: '-', key: '-');
  static const slash = ExtraKey(label: '/', key: '/');
  static const pipe = ExtraKey(label: '|', key: '|');
  static const backslash = ExtraKey(label: '\\', key: '\\');
  static const underscore = ExtraKey(label: '_', key: '_');

  /// 默认按键行布局
  static const List<List<ExtraKey>> defaultLayout = [
    [esc, tab, ctrl, alt, dash, underscore, up, slash],
    [home, end, pgup, pgdn, left, down, right, pipe],
  ];

  /// 简单按键行布局（单行）
  static const List<ExtraKey> simpleLayout = [
    esc, tab, ctrl, alt, left, up, down, right,
  ];
}

/// 额外按键视图
class ExtraKeysView extends StatefulWidget {
  final Function(String) onKeyTap;
  final VoidCallback? onCtrlToggle;
  final VoidCallback? onAltToggle;
  final bool vibrationEnabled;

  const ExtraKeysView({
    super.key,
    required this.onKeyTap,
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
    } else if (key.key != null) {
      String keyToSend = key.key!;

      // 处理 Ctrl 组合键
      if (_ctrlPressed && keyToSend.length == 1) {
        final char = keyToSend.codeUnitAt(0);
        if (char >= 0x61 && char <= 0x7a) {
          // a-z
          keyToSend = String.fromCharCode(char - 0x60);
        } else if (char >= 0x41 && char <= 0x5a) {
          // A-Z
          keyToSend = String.fromCharCode(char - 0x40);
        }
        setState(() => _ctrlPressed = false);
      }

      // 处理 Alt 组合键
      if (_altPressed) {
        keyToSend = '\x1b$keyToSend';
        setState(() => _altPressed = false);
      }

      widget.onKeyTap(keyToSend);
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
  final Function(String) onKeyTap;
  final bool vibrationEnabled;

  const FullExtraKeysView({
    super.key,
    required this.onKeyTap,
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
    } else if (key.key != null) {
      String keyToSend = key.key!;

      if (_ctrlPressed && keyToSend.length == 1) {
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

      widget.onKeyTap(keyToSend);
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
