import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

/// 额外按键组件
/// 参考 termux-app: ExtraKeysView.java, ExtraKeyButton.java

/// 按键定义
class ExtraKey {
  final String label;
  final String? displayLabel;
  final String? text; // 普通文本字符
  final TerminalKey? terminalKey; // xterm特殊按键
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
  // 功能键
  static const esc = ExtraKey(label: 'ESC', terminalKey: TerminalKey.escape);
  static const tab = ExtraKey(label: 'TAB', terminalKey: TerminalKey.tab);
  static const ctrl = ExtraKey(label: 'CTRL', isModifier: true);
  static const alt = ExtraKey(label: 'ALT', isModifier: true);

  // 导航键
  static const home = ExtraKey(label: 'HOME', displayLabel: 'HOME', terminalKey: TerminalKey.home);
  static const end = ExtraKey(label: 'END', displayLabel: 'END', terminalKey: TerminalKey.end);
  static const pgup =
      ExtraKey(label: 'PGUP', displayLabel: 'PGUP', terminalKey: TerminalKey.pageUp);
  static const pgdn =
      ExtraKey(label: 'PGDN', displayLabel: 'PGDN', terminalKey: TerminalKey.pageDown);
  static const insert =
      ExtraKey(label: 'INS', displayLabel: 'INS', terminalKey: TerminalKey.insert);

  // 方向键
  static const up = ExtraKey(
      label: 'UP', terminalKey: TerminalKey.arrowUp, icon: Icons.keyboard_arrow_up);
  static const down = ExtraKey(
      label: 'DOWN', terminalKey: TerminalKey.arrowDown, icon: Icons.keyboard_arrow_down);
  static const left = ExtraKey(
      label: 'LEFT', terminalKey: TerminalKey.arrowLeft, icon: Icons.keyboard_arrow_left);
  static const right = ExtraKey(
      label: 'RIGHT',
      terminalKey: TerminalKey.arrowRight,
      icon: Icons.keyboard_arrow_right);

  // 编辑键
  static const enter =
      ExtraKey(label: 'ENTER', displayLabel: '↲', terminalKey: TerminalKey.enter);
  static const backspace =
      ExtraKey(label: 'DEL', displayLabel: '⌫', terminalKey: TerminalKey.backspace);
  static const deleteKey =
      ExtraKey(label: 'FORWARD_DEL', displayLabel: 'DEL', terminalKey: TerminalKey.delete);

  // 常用符号
  static const dash = ExtraKey(label: '-', text: '-');
  static const slash = ExtraKey(label: '/', text: '/');
  static const pipe = ExtraKey(label: '|', text: '|');
  static const backslash = ExtraKey(label: '\\', text: '\\');
  static const underscore = ExtraKey(label: '_', text: '_');
  static const tilde = ExtraKey(label: '~', text: '~');
  static const at = ExtraKey(label: '@', text: '@');
  static const hash = ExtraKey(label: '#', text: '#');
  static const dollar = ExtraKey(label: '\$', text: '\$');
  static const percent = ExtraKey(label: '%', text: '%');
  static const caret = ExtraKey(label: '^', text: '^');
  static const ampersand = ExtraKey(label: '&', text: '&');
  static const asterisk = ExtraKey(label: '*', text: '*');
  static const equals = ExtraKey(label: '=', text: '=');
  static const plus = ExtraKey(label: '+', text: '+');
  static const colon = ExtraKey(label: ':', text: ':');
  static const semicolon = ExtraKey(label: ';', text: ';');
  static const quote = ExtraKey(label: "'", text: "'");
  static const doubleQuote = ExtraKey(label: '"', text: '"');
  static const backtick = ExtraKey(label: '`', text: '`');
  static const exclamation = ExtraKey(label: '!', text: '!');
  static const question = ExtraKey(label: '?', text: '?');
  static const lessThan = ExtraKey(label: '<', text: '<');
  static const greaterThan = ExtraKey(label: '>', text: '>');

  // 括号
  static const leftParen = ExtraKey(label: '(', text: '(');
  static const rightParen = ExtraKey(label: ')', text: ')');
  static const leftBracket = ExtraKey(label: '[', text: '[');
  static const rightBracket = ExtraKey(label: ']', text: ']');
  static const leftBrace = ExtraKey(label: '{', text: '{');
  static const rightBrace = ExtraKey(label: '}', text: '}');

  // 功能键 F1-F12
  static const f1 = ExtraKey(label: 'F1', terminalKey: TerminalKey.f1);
  static const f2 = ExtraKey(label: 'F2', terminalKey: TerminalKey.f2);
  static const f3 = ExtraKey(label: 'F3', terminalKey: TerminalKey.f3);
  static const f4 = ExtraKey(label: 'F4', terminalKey: TerminalKey.f4);
  static const f5 = ExtraKey(label: 'F5', terminalKey: TerminalKey.f5);
  static const f6 = ExtraKey(label: 'F6', terminalKey: TerminalKey.f6);
  static const f7 = ExtraKey(label: 'F7', terminalKey: TerminalKey.f7);
  static const f8 = ExtraKey(label: 'F8', terminalKey: TerminalKey.f8);
  static const f9 = ExtraKey(label: 'F9', terminalKey: TerminalKey.f9);
  static const f10 = ExtraKey(label: 'F10', terminalKey: TerminalKey.f10);
  static const f11 = ExtraKey(label: 'F11', terminalKey: TerminalKey.f11);
  static const f12 = ExtraKey(label: 'F12', terminalKey: TerminalKey.f12);
}

/// 快捷命令定义
class QuickCommand {
  final String label;
  final String command;
  final IconData? icon;

  const QuickCommand({
    required this.label,
    required this.command,
    this.icon,
  });

  static const List<QuickCommand> commands = [
    QuickCommand(label: 'clear', command: 'clear\n'),
    QuickCommand(label: 'ls -la', command: 'ls -la\n'),
    QuickCommand(label: 'cd ..', command: 'cd ..\n'),
    QuickCommand(label: 'pwd', command: 'pwd\n'),
    QuickCommand(label: 'exit', command: 'exit\n'),
    QuickCommand(label: 'history', command: 'history\n'),
    QuickCommand(label: 'top', command: 'top\n'),
    QuickCommand(label: 'htop', command: 'htop\n'),
  ];

  /// Termux 兼容命令
  static const List<QuickCommand> termuxCommands = [
    QuickCommand(label: 'setup-storage', command: 'termux-setup-storage\n', icon: Icons.folder_open),
    QuickCommand(label: 'pkg install', command: 'pkg install '),
    QuickCommand(label: 'pkg search', command: 'pkg search '),
    QuickCommand(label: 'pkg list', command: 'pkg list-installed\n'),
    QuickCommand(label: 'pkg upgrade', command: 'pkg upgrade\n'),
    QuickCommand(label: 'pkg update', command: 'pkg update\n'),
    QuickCommand(label: 'apt install', command: 'apt install '),
    QuickCommand(label: 'apt update', command: 'apt update\n'),
  ];
}

/// 新版额外按键视图 - 带展开功能
class ExtraKeysView extends StatefulWidget {
  final Function(String) onTextKeyTap;
  final Function(TerminalKey) onTerminalKeyTap;
  final VoidCallback? onCtrlToggle;
  final VoidCallback? onAltToggle;
  final bool vibrationEnabled;
  // 外部控制的修饰键状态（用于音量键同步）
  final bool ctrlPressed;
  final bool altPressed;
  final List<QuickCommand>? customCommands; // 自定义命令

  const ExtraKeysView({
    super.key,
    required this.onTextKeyTap,
    required this.onTerminalKeyTap,
    this.onCtrlToggle,
    this.onAltToggle,
    this.vibrationEnabled = true,
    this.ctrlPressed = false,
    this.altPressed = false,
    this.customCommands,
  });

  @override
  State<ExtraKeysView> createState() => _ExtraKeysViewState();
}

class _ExtraKeysViewState extends State<ExtraKeysView>
    with SingleTickerProviderStateMixin {
  bool _localCtrlPressed = false;
  bool _localAltPressed = false;
  bool _expanded = false;
  int _expandedTab = 0; // 0: 符号, 1: 功能键, 2: 快捷命令, 3: 导航, 4: Termux

  // 长按重复计时器
  Timer? _repeatTimer;
  static const _repeatDelay = Duration(milliseconds: 400); // 首次延迟
  static const _repeatInterval = Duration(milliseconds: 50); // 重复间隔

  // 使用外部状态或本地状态
  bool get _ctrlPressed => widget.ctrlPressed || _localCtrlPressed;
  bool get _altPressed => widget.altPressed || _localAltPressed;

  void _handleKeyTap(ExtraKey key) {
    if (widget.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    if (key.isModifier) {
      if (key.label == 'CTRL') {
        // 如果有外部控制，通过回调通知
        if (widget.onCtrlToggle != null) {
          widget.onCtrlToggle!();
        } else {
          setState(() => _localCtrlPressed = !_localCtrlPressed);
        }
      } else if (key.label == 'ALT') {
        if (widget.onAltToggle != null) {
          widget.onAltToggle!();
        } else {
          setState(() => _localAltPressed = !_localAltPressed);
        }
      }
    } else if (key.terminalKey != null) {
      widget.onTerminalKeyTap(key.terminalKey!);
      _resetModifiers();
    } else if (key.text != null) {
      String keyToSend = key.text!;

      if (_ctrlPressed) {
        final char = keyToSend.codeUnitAt(0);
        if (char >= 0x61 && char <= 0x7a) {
          keyToSend = String.fromCharCode(char - 0x60);
        } else if (char >= 0x41 && char <= 0x5a) {
          keyToSend = String.fromCharCode(char - 0x40);
        }
      }

      if (_altPressed) {
        keyToSend = '\x1b$keyToSend';
      }

      widget.onTextKeyTap(keyToSend);
      _resetModifiers();
    }
  }

  void _resetModifiers() {
    setState(() {
      _localCtrlPressed = false;
      _localAltPressed = false;
    });
    // 如果有外部控制，也需要重置
    if (widget.ctrlPressed && widget.onCtrlToggle != null) {
      widget.onCtrlToggle!();
    }
    if (widget.altPressed && widget.onAltToggle != null) {
      widget.onAltToggle!();
    }
  }

  void _handleCommandTap(QuickCommand cmd) {
    if (widget.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
    widget.onTextKeyTap(cmd.command);
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  /// 开始长按重复
  void _startRepeat(ExtraKey key) {
    _stopRepeat();
    // 首次按下立即触发
    _handleKeyTap(key);
    // 延迟后开始重复
    _repeatTimer = Timer(_repeatDelay, () {
      _repeatTimer = Timer.periodic(_repeatInterval, (_) {
        _handleKeyTap(key);
      });
    });
  }

  /// 停止长按重复
  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 展开面板
          if (_expanded) _buildExpandedPanel(theme),
          // 主键盘行
          _buildMainRow(theme),
        ],
      ),
    );
  }

  /// 主键盘行 - 两行布局，方向键在右侧
  Widget _buildMainRow(ThemeData theme) {
    return SizedBox(
      height: 76, // 38 * 2
      child: Row(
        children: [
          // 左侧主键区 (占 4/7 宽度)
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // 第一行: ESC, CTRL, ALT, -
                Expanded(
                  child: Row(
                    children: [
                      _buildKey(ExtraKeys.esc, theme),
                      _buildKey(ExtraKeys.ctrl, theme),
                      _buildKey(ExtraKeys.alt, theme),
                      _buildKey(ExtraKeys.dash, theme),
                    ],
                  ),
                ),
                // 第二行: TAB, /, Tasks, 展开
                Expanded(
                  child: Row(
                    children: [
                      _buildKey(ExtraKeys.tab, theme),
                      _buildKey(ExtraKeys.slash, theme),
                      // 快捷指令入口
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Material(
                            color: _expanded && _expandedTab == 2
                                ? theme.colorScheme.tertiaryContainer
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: () {
                                if (widget.vibrationEnabled) {
                                  HapticFeedback.lightImpact();
                                }
                                setState(() {
                                  if (_expanded && _expandedTab == 2) {
                                    _expanded = false; // 如果已经在任务面板，则关闭
                                  } else {
                                    _expanded = true;
                                    _expandedTab = 2; // 切换到命令 Tab (index 2)
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Center(
                                child: Icon(
                                  Icons.flash_on,
                                  size: 18,
                                  color: _expanded && _expandedTab == 2
                                      ? theme.colorScheme.onTertiaryContainer
                                      : theme.colorScheme.primary, // 使用主色突出
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildExpandButton(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右侧方向键区 (占 3/7 宽度)
          Expanded(
            flex: 3,
            child: _buildArrowKeysCluster(theme),
          ),
        ],
      ),
    );
  }

  /// 方向键十字布局 + Home/End (自适应宽度)
  Widget _buildArrowKeysCluster(ThemeData theme) {
    return Column(
      children: [
        // 上方行：Home, Up, End
        Expanded(
          child: Row(
            children: [
              _buildArrowKey(ExtraKeys.home, theme),
              _buildArrowKey(ExtraKeys.up, theme),
              _buildArrowKey(ExtraKeys.end, theme),
            ],
          ),
        ),
        // 下方行：Left, Down, Right
        Expanded(
          child: Row(
            children: [
              _buildArrowKey(ExtraKeys.left, theme),
              _buildArrowKey(ExtraKeys.down, theme),
              _buildArrowKey(ExtraKeys.right, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// 方向键按钮 (自适应宽度，支持长按重复)
  Widget _buildArrowKey(ExtraKey key, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          onTapDown: (_) => _startRepeat(key),
          onTapUp: (_) => _stopRepeat(),
          onTapCancel: () => _stopRepeat(),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: key.icon != null
                  ? Icon(
                      key.icon,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        key.displayLabel ?? key.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 展开按钮
  Widget _buildExpandButton(ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: _expanded
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () {
              if (widget.vibrationEnabled) {
                HapticFeedback.lightImpact();
              }
              setState(() => _expanded = !_expanded);
            },
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: Icon(
                _expanded ? Icons.keyboard_arrow_down : Icons.apps,
                size: 18,
                color: _expanded
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 展开的面板
  Widget _buildExpandedPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab 切换栏
          SizedBox(
            height: 32,
            child: Row(
              children: [
                _buildTabButton('符号', 0, theme),
                _buildTabButton('F键', 1, theme),
                _buildTabButton('命令', 2, theme),
                _buildTabButton('导航', 3, theme),
                _buildTabButton('Termux', 4, theme),
              ],
            ),
          ),
          // 内容区域
          _buildTabContent(theme),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, ThemeData theme) {
    final isSelected = _expandedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (widget.vibrationEnabled) {
            HapticFeedback.selectionClick();
          }
          setState(() => _expandedTab = index);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme) {
    switch (_expandedTab) {
      case 0:
        return _buildSymbolsPanel(theme);
      case 1:
        return _buildFunctionKeysPanel(theme);
      case 2:
        return _buildCommandsPanel(theme);
      case 3:
        return _buildNavigationPanel(theme);
      case 4:
        return _buildTermuxPanel(theme);
      default:
        return _buildSymbolsPanel(theme);
    }
  }

  /// 符号面板
  Widget _buildSymbolsPanel(ThemeData theme) {
    final symbols = [
      // 第一行
      [
        ExtraKeys.tilde,
        ExtraKeys.backtick,
        ExtraKeys.exclamation,
        ExtraKeys.at,
        ExtraKeys.hash,
        ExtraKeys.dollar,
        ExtraKeys.percent,
        ExtraKeys.caret,
      ],
      // 第二行
      [
        ExtraKeys.ampersand,
        ExtraKeys.asterisk,
        ExtraKeys.leftParen,
        ExtraKeys.rightParen,
        ExtraKeys.underscore,
        ExtraKeys.plus,
        ExtraKeys.equals,
        ExtraKeys.backslash,
      ],
      // 第三行
      [
        ExtraKeys.leftBracket,
        ExtraKeys.rightBracket,
        ExtraKeys.leftBrace,
        ExtraKeys.rightBrace,
        ExtraKeys.lessThan,
        ExtraKeys.greaterThan,
        ExtraKeys.question,
        ExtraKeys.colon,
      ],
      // 第四行
      [
        ExtraKeys.semicolon,
        ExtraKeys.quote,
        ExtraKeys.doubleQuote,
      ],
    ];

    return Column(
      children: symbols.map((row) => _buildSymbolRow(row, theme)).toList(),
    );
  }

  Widget _buildSymbolRow(List<ExtraKey> keys, ThemeData theme) {
    return SizedBox(
      height: 36,
      child: Row(
        children: keys.map((key) => _buildKey(key, theme, fontSize: 14)).toList(),
      ),
    );
  }

  /// 功能键面板
  Widget _buildFunctionKeysPanel(ThemeData theme) {
    final fKeys = [
      [
        ExtraKeys.f1,
        ExtraKeys.f2,
        ExtraKeys.f3,
        ExtraKeys.f4,
        ExtraKeys.f5,
        ExtraKeys.f6,
      ],
      [
        ExtraKeys.f7,
        ExtraKeys.f8,
        ExtraKeys.f9,
        ExtraKeys.f10,
        ExtraKeys.f11,
        ExtraKeys.f12,
      ],
    ];

    return Column(
      children: fKeys.map((row) {
        return SizedBox(
          height: 36,
          child: Row(
            children: row.map((key) => _buildKey(key, theme, fontSize: 11)).toList(),
          ),
        );
      }).toList(),
    );
  }

  /// 快捷命令面板 - 优化为横向滚动
  Widget _buildCommandsPanel(ThemeData theme) {
    final allCommands = [
      ...?widget.customCommands,
      ...QuickCommand.commands,
    ];

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: allCommands.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cmd = allCommands[index];
          return Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            // elevation: 1, // 扁平化风格更好
            child: InkWell(
              onTap: () => _handleCommandTap(cmd),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 72),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cmd.icon != null) ...[
                      Icon(cmd.icon, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      cmd.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 导航键面板
  Widget _buildNavigationPanel(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _buildKey(ExtraKeys.pgup, theme),
          _buildKey(ExtraKeys.pgdn, theme),
          _buildKey(ExtraKeys.insert, theme),
          _buildKey(ExtraKeys.deleteKey, theme),
        ],
      ),
    );
  }

  /// Termux 命令面板
  Widget _buildTermuxPanel(ThemeData theme) {
    return SizedBox(
      height: 72,
      child: GridView.count(
        crossAxisCount: 4,
        childAspectRatio: 2.5,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        children: QuickCommand.termuxCommands.map((cmd) {
          return Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: () => _handleCommandTap(cmd),
                borderRadius: BorderRadius.circular(4),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cmd.icon != null) ...[
                        Icon(
                          cmd.icon,
                          size: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          cmd.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKey(ExtraKey key, ThemeData theme, {double fontSize = 12}) {
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
                      size: 18,
                      color: isPressed
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        key.display,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: fontSize,
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
      ),
    );
  }
}

/// 完整的额外按键视图（两行）- 保留兼容
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
  @override
  Widget build(BuildContext context) {
    return ExtraKeysView(
      onTextKeyTap: widget.onTextKeyTap,
      onTerminalKeyTap: widget.onTerminalKeyTap,
      vibrationEnabled: widget.vibrationEnabled,
    );
  }
}
