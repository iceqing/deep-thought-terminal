import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../l10n/app_localizations.dart';
import '../models/extra_key_layout.dart';

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
  static const esc =
      ExtraKey(label: ExtraKeyIds.esc, terminalKey: TerminalKey.escape);
  static const tab =
      ExtraKey(label: ExtraKeyIds.tab, terminalKey: TerminalKey.tab);
  static const ctrl = ExtraKey(label: ExtraKeyIds.ctrl, isModifier: true);
  static const alt = ExtraKey(label: ExtraKeyIds.alt, isModifier: true);
  static const menu = ExtraKey(
    label: ExtraKeyIds.menu,
    displayLabel: '⋯',
    icon: Icons.apps,
  );

  // 导航键
  static const home = ExtraKey(
      label: ExtraKeyIds.home,
      displayLabel: 'HOME',
      terminalKey: TerminalKey.home);
  static const end = ExtraKey(
      label: ExtraKeyIds.end,
      displayLabel: 'END',
      terminalKey: TerminalKey.end);
  static const pgup = ExtraKey(
      label: ExtraKeyIds.pgup,
      displayLabel: 'PGUP',
      terminalKey: TerminalKey.pageUp);
  static const pgdn = ExtraKey(
      label: ExtraKeyIds.pgdn,
      displayLabel: 'PGDN',
      terminalKey: TerminalKey.pageDown);
  static const insert = ExtraKey(
      label: ExtraKeyIds.insert,
      displayLabel: 'INS',
      terminalKey: TerminalKey.insert);

  // 方向键
  static const up = ExtraKey(
      label: ExtraKeyIds.up,
      terminalKey: TerminalKey.arrowUp,
      icon: Icons.keyboard_arrow_up);
  static const down = ExtraKey(
      label: ExtraKeyIds.down,
      terminalKey: TerminalKey.arrowDown,
      icon: Icons.keyboard_arrow_down);
  static const left = ExtraKey(
      label: ExtraKeyIds.left,
      terminalKey: TerminalKey.arrowLeft,
      icon: Icons.keyboard_arrow_left);
  static const right = ExtraKey(
      label: ExtraKeyIds.right,
      terminalKey: TerminalKey.arrowRight,
      icon: Icons.keyboard_arrow_right);

  // 编辑键
  static const enter = ExtraKey(
      label: ExtraKeyIds.enter,
      displayLabel: '↲',
      terminalKey: TerminalKey.enter);
  static const backspace = ExtraKey(
      label: ExtraKeyIds.backspace,
      displayLabel: '⌫',
      terminalKey: TerminalKey.backspace);
  static const deleteKey = ExtraKey(
      label: ExtraKeyIds.deleteKey,
      displayLabel: 'DEL',
      terminalKey: TerminalKey.delete);

  // 常用符号
  static const minus = ExtraKey(label: ExtraKeyIds.minus, text: '-');
  static const slash = ExtraKey(label: ExtraKeyIds.slash, text: '/');
  static const pipe = ExtraKey(label: ExtraKeyIds.pipe, text: '|');
  static const backslash = ExtraKey(label: ExtraKeyIds.backslash, text: '\\');
  static const underscore = ExtraKey(label: ExtraKeyIds.underscore, text: '_');
  static const tilde = ExtraKey(label: ExtraKeyIds.tilde, text: '~');
  static const at = ExtraKey(label: ExtraKeyIds.at, text: '@');
  static const hash = ExtraKey(label: ExtraKeyIds.hash, text: '#');
  static const dollar = ExtraKey(label: ExtraKeyIds.dollar, text: '\$');
  static const percent = ExtraKey(label: ExtraKeyIds.percent, text: '%');
  static const caret = ExtraKey(label: ExtraKeyIds.caret, text: '^');
  static const ampersand = ExtraKey(label: ExtraKeyIds.ampersand, text: '&');
  static const asterisk = ExtraKey(label: ExtraKeyIds.asterisk, text: '*');
  static const equals = ExtraKey(label: ExtraKeyIds.equals, text: '=');
  static const plus = ExtraKey(label: ExtraKeyIds.plus, text: '+');
  static const colon = ExtraKey(label: ExtraKeyIds.colon, text: ':');
  static const semicolon = ExtraKey(label: ExtraKeyIds.semicolon, text: ';');
  static const quote = ExtraKey(label: ExtraKeyIds.quote, text: "'");
  static const doubleQuote =
      ExtraKey(label: ExtraKeyIds.doubleQuote, text: '"');
  static const backtick = ExtraKey(label: ExtraKeyIds.backtick, text: '`');
  static const exclamation =
      ExtraKey(label: ExtraKeyIds.exclamation, text: '!');
  static const question = ExtraKey(label: ExtraKeyIds.question, text: '?');
  static const lessThan = ExtraKey(label: ExtraKeyIds.lessThan, text: '<');
  static const greaterThan =
      ExtraKey(label: ExtraKeyIds.greaterThan, text: '>');
  static const append = ExtraKey(label: ExtraKeyIds.append, text: '>>');
  static const and = ExtraKey(label: ExtraKeyIds.and, text: '&&');

  // 括号
  static const leftParen = ExtraKey(label: ExtraKeyIds.leftParen, text: '(');
  static const rightParen = ExtraKey(label: ExtraKeyIds.rightParen, text: ')');
  static const leftBracket =
      ExtraKey(label: ExtraKeyIds.leftBracket, text: '[');
  static const rightBracket =
      ExtraKey(label: ExtraKeyIds.rightBracket, text: ']');
  static const leftBrace = ExtraKey(label: ExtraKeyIds.leftBrace, text: '{');
  static const rightBrace = ExtraKey(label: ExtraKeyIds.rightBrace, text: '}');

  // 功能键 F1-F12
  static const f1 =
      ExtraKey(label: ExtraKeyIds.f1, terminalKey: TerminalKey.f1);
  static const f2 =
      ExtraKey(label: ExtraKeyIds.f2, terminalKey: TerminalKey.f2);
  static const f3 =
      ExtraKey(label: ExtraKeyIds.f3, terminalKey: TerminalKey.f3);
  static const f4 =
      ExtraKey(label: ExtraKeyIds.f4, terminalKey: TerminalKey.f4);
  static const f5 =
      ExtraKey(label: ExtraKeyIds.f5, terminalKey: TerminalKey.f5);
  static const f6 =
      ExtraKey(label: ExtraKeyIds.f6, terminalKey: TerminalKey.f6);
  static const f7 =
      ExtraKey(label: ExtraKeyIds.f7, terminalKey: TerminalKey.f7);
  static const f8 =
      ExtraKey(label: ExtraKeyIds.f8, terminalKey: TerminalKey.f8);
  static const f9 =
      ExtraKey(label: ExtraKeyIds.f9, terminalKey: TerminalKey.f9);
  static const f10 =
      ExtraKey(label: ExtraKeyIds.f10, terminalKey: TerminalKey.f10);
  static const f11 =
      ExtraKey(label: ExtraKeyIds.f11, terminalKey: TerminalKey.f11);
  static const f12 =
      ExtraKey(label: ExtraKeyIds.f12, terminalKey: TerminalKey.f12);

  static const all = [
    esc,
    tab,
    ctrl,
    alt,
    home,
    end,
    pgup,
    pgdn,
    insert,
    up,
    down,
    left,
    right,
    enter,
    backspace,
    deleteKey,
    minus,
    slash,
    pipe,
    backslash,
    underscore,
    tilde,
    at,
    hash,
    dollar,
    percent,
    caret,
    ampersand,
    asterisk,
    equals,
    plus,
    colon,
    semicolon,
    quote,
    doubleQuote,
    backtick,
    exclamation,
    question,
    lessThan,
    greaterThan,
    append,
    and,
    leftParen,
    rightParen,
    leftBracket,
    rightBracket,
    leftBrace,
    rightBrace,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    menu,
  ];

  static final Map<String, ExtraKey> byId = {
    for (final key in all) key.label: key,
  };

  static ExtraKey? fromId(String keyId) => byId[keyId];

  static String visualLabel(String keyId) {
    return fromId(keyId)?.display ?? keyId;
  }

  static String localizedLabel(BuildContext context, String keyId) {
    final l10n = AppLocalizations.of(context);
    switch (keyId) {
      case ExtraKeyIds.esc:
        return l10n.keyEsc;
      case ExtraKeyIds.tab:
        return l10n.keyTab;
      case ExtraKeyIds.ctrl:
        return l10n.keyCtrl;
      case ExtraKeyIds.alt:
        return l10n.keyAlt;
      case ExtraKeyIds.home:
        return l10n.keyHome;
      case ExtraKeyIds.end:
        return l10n.keyEnd;
      case ExtraKeyIds.pgup:
        return l10n.keyPgUp;
      case ExtraKeyIds.pgdn:
        return l10n.keyPgDn;
      case ExtraKeyIds.insert:
        return l10n.keyIns;
      case ExtraKeyIds.deleteKey:
        return l10n.keyDel;
      case ExtraKeyIds.enter:
        return l10n.keyEnter;
      case ExtraKeyIds.backspace:
        return l10n.keyBackspace;
      case ExtraKeyIds.menu:
        return l10n.extraKeysMenu;
      default:
        return fromId(keyId)?.display ?? keyId;
    }
  }
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
    QuickCommand(
      label: 'Storage',
      command: 'setup-storage\n',
      icon: Icons.folder_open,
    ),
    QuickCommand(
      label: 'Pkg Install',
      command: 'pkg install ',
      icon: Icons.download_rounded,
    ),
    QuickCommand(
      label: 'Pkg Search',
      command: 'pkg search ',
      icon: Icons.search_rounded,
    ),
    QuickCommand(
      label: 'Pkg List',
      command: 'pkg list-installed\n',
      icon: Icons.inventory_2_rounded,
    ),
    QuickCommand(
      label: 'Pkg Upgrade',
      command: 'pkg upgrade\n',
      icon: Icons.system_update_alt_rounded,
    ),
    QuickCommand(
      label: 'Pkg Update',
      command: 'pkg update\n',
      icon: Icons.sync_rounded,
    ),
    QuickCommand(
      label: 'Apt Install',
      command: 'apt install ',
      icon: Icons.archive_rounded,
    ),
    QuickCommand(
      label: 'Apt Update',
      command: 'apt update\n',
      icon: Icons.cloud_download_rounded,
    ),
  ];
}

/// 新版额外按键视图 - 带展开功能
class ExtraKeysView extends StatefulWidget {
  final Function(String) onTextKeyTap;
  final Function(TerminalKey) onTerminalKeyTap;
  final VoidCallback? onCtrlToggle;
  final VoidCallback? onAltToggle;
  final bool vibrationEnabled;
  final ExtraKeysLayoutConfig? layoutConfig;
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
    this.layoutConfig,
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
      if (key.label == ExtraKeyIds.ctrl) {
        // 如果有外部控制，通过回调通知
        if (widget.onCtrlToggle != null) {
          widget.onCtrlToggle!();
        } else {
          setState(() => _localCtrlPressed = !_localCtrlPressed);
        }
      } else if (key.label == ExtraKeyIds.alt) {
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
    final isWideLayout = _isWideLayout(context);
    final layout = widget.layoutConfig ?? ExtraKeysLayoutConfig.defaults();

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 展开面板
          if (_expanded) _buildExpandedPanel(theme, isWideLayout),
          // 主键盘行
          _buildMainRow(theme, isWideLayout, layout),
        ],
      ),
    );
  }

  bool _isWideLayout(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.shortestSide >= 600 || mediaQuery.size.width >= 900;
  }

  /// 主键盘行 - 两行布局，方向键在右侧
  Widget _buildMainRow(
    ThemeData theme,
    bool isWideLayout,
    ExtraKeysLayoutConfig layout,
  ) {
    final topRow = layout.rows[0];
    final bottomRow = layout.rows[1];

    return SizedBox(
      height: isWideLayout ? 84 : 76,
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
                      for (final keyId in topRow.take(4))
                        _buildConfiguredKey(keyId, theme),
                    ],
                  ),
                ),
                // 第二行: TAB, /, Enter, 展开
                Expanded(
                  child: Row(
                    children: [
                      for (final keyId in bottomRow.take(4))
                        _buildConfiguredKey(keyId, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右侧方向键区 (占 3/7 宽度)
          Expanded(
            flex: 3,
            child: _buildArrowKeysCluster(theme, topRow, bottomRow),
          ),
        ],
      ),
    );
  }

  /// 方向键十字布局 + Home/End (自适应宽度)
  Widget _buildArrowKeysCluster(
    ThemeData theme,
    List<String> topRow,
    List<String> bottomRow,
  ) {
    return Column(
      children: [
        // 上方行：Home, Up, End
        Expanded(
          child: Row(
            children: [
              for (final keyId in topRow.skip(4))
                _buildCompactKey(keyId, theme),
            ],
          ),
        ),
        // 下方行：Left, Down, Right
        Expanded(
          child: Row(
            children: [
              for (final keyId in bottomRow.skip(4))
                _buildCompactKey(keyId, theme),
            ],
          ),
        ),
      ],
    );
  }

  /// 方向键按钮 (自适应宽度，支持长按重复)
  Widget _buildCompactKey(String keyId, ThemeData theme) {
    if (keyId == ExtraKeyIds.menu) {
      return _buildExpandButton(theme);
    }

    final key = ExtraKeys.fromId(keyId);
    if (key == null) {
      return _buildMissingKey(theme, keyId);
    }

    final content = Center(
      child: key.icon != null
          ? Icon(
              key.icon,
              size: 18,
              color: theme.colorScheme.onSurface,
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ExtraKeys.localizedLabel(context, keyId),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          child: _isRepeatableKey(key)
              ? GestureDetector(
                  onTapDown: (_) => _startRepeat(key),
                  onTapUp: (_) => _stopRepeat(),
                  onTapCancel: _stopRepeat,
                  child: content,
                )
              : InkWell(
                  onTap: () => _handleKeyTap(key),
                  borderRadius: BorderRadius.circular(4),
                  child: content,
                ),
        ),
      ),
    );
  }

  Widget _buildConfiguredKey(String keyId, ThemeData theme) {
    if (keyId == ExtraKeyIds.menu) {
      return _buildExpandButton(theme);
    }

    final key = ExtraKeys.fromId(keyId);
    if (key == null) {
      return _buildMissingKey(theme, keyId);
    }

    return _buildKey(key, theme);
  }

  Widget _buildMissingKey(ThemeData theme, String keyId) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              keyId,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isRepeatableKey(ExtraKey key) {
    switch (key.label) {
      case ExtraKeyIds.up:
      case ExtraKeyIds.down:
      case ExtraKeyIds.left:
      case ExtraKeyIds.right:
      case ExtraKeyIds.home:
      case ExtraKeyIds.end:
      case ExtraKeyIds.pgup:
      case ExtraKeyIds.pgdn:
      case ExtraKeyIds.backspace:
      case ExtraKeyIds.deleteKey:
        return true;
      default:
        return false;
    }
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
  Widget _buildExpandedPanel(ThemeData theme, bool isWideLayout) {
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
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _buildTabButton(
                    AppLocalizations.of(context).categorySymbols,
                    0,
                    theme,
                  ),
                  _buildTabButton(
                    AppLocalizations.of(context).categoryFKeys,
                    1,
                    theme,
                  ),
                  _buildTabButton(
                    AppLocalizations.of(context).categoryCommands,
                    2,
                    theme,
                  ),
                  _buildTabButton(
                    AppLocalizations.of(context).categoryNav,
                    3,
                    theme,
                  ),
                  _buildTabButton(
                    AppLocalizations.of(context).categoryTermux,
                    4,
                    theme,
                  ),
                ],
              ),
            ),
          ),
          // 内容区域
          _buildTabContent(theme, isWideLayout),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, ThemeData theme) {
    final isSelected = _expandedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (widget.vibrationEnabled) {
            HapticFeedback.selectionClick();
          }
          setState(() => _expandedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, bool isWideLayout) {
    switch (_expandedTab) {
      case 0:
        return _buildSymbolsPanel(theme);
      case 1:
        return _buildFunctionKeysPanel(theme);
      case 2:
        return _buildCommandsPanel(theme, isWideLayout);
      case 3:
        return _buildNavigationPanel(theme);
      case 4:
        return _buildTermuxPanel(theme, isWideLayout);
      default:
        return _buildSymbolsPanel(theme);
    }
  }

  /// 符号面板
  Widget _buildSymbolsPanel(ThemeData theme) {
    final symbols = [
      // 第一行: 核心终端符号
      [
        ExtraKeys.pipe,
        ExtraKeys.greaterThan,
        ExtraKeys.append,
        ExtraKeys.ampersand,
        ExtraKeys.and,
        ExtraKeys.semicolon,
        ExtraKeys.backslash,
        ExtraKeys.slash,
      ],
      // 第二行: 基础符号
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
      // 第三行: 数学与逻辑
      [
        ExtraKeys.asterisk,
        ExtraKeys.plus,
        ExtraKeys.minus,
        ExtraKeys.equals,
        ExtraKeys.underscore,
        ExtraKeys.colon,
        ExtraKeys.lessThan,
        ExtraKeys.question,
      ],
      // 第四行: 括号与引号
      [
        ExtraKeys.leftParen,
        ExtraKeys.rightParen,
        ExtraKeys.leftBracket,
        ExtraKeys.rightBracket,
        ExtraKeys.leftBrace,
        ExtraKeys.rightBrace,
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
        children:
            keys.map((key) => _buildKey(key, theme, fontSize: 14)).toList(),
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
            children:
                row.map((key) => _buildKey(key, theme, fontSize: 11)).toList(),
          ),
        );
      }).toList(),
    );
  }

  /// 快捷命令面板 - 平板使用自适应网格
  Widget _buildCommandsPanel(ThemeData theme, bool isWideLayout) {
    final allCommands = [
      ...?widget.customCommands,
      ...QuickCommand.commands,
    ];

    if (!isWideLayout) {
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
                        Icon(
                          cmd.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
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

    return _buildCommandGrid(
      theme,
      allCommands,
      baseColumns: 4,
      accent: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
      foreground: theme.colorScheme.onSecondaryContainer,
      iconColor: theme.colorScheme.secondary,
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
  Widget _buildTermuxPanel(ThemeData theme, bool isWideLayout) {
    return _buildCommandGrid(
      theme,
      QuickCommand.termuxCommands,
      baseColumns: isWideLayout ? 5 : 4,
      accent: theme.colorScheme.primaryContainer.withValues(alpha: 0.62),
      foreground: theme.colorScheme.onPrimaryContainer,
      iconColor: theme.colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildCommandGrid(
    ThemeData theme,
    List<QuickCommand> commands, {
    required int baseColumns,
    required Color accent,
    required Color foreground,
    required Color iconColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1080
            ? baseColumns + 2
            : width >= 820
                ? baseColumns + 1
                : baseColumns;
        final rows = (commands.length / crossAxisCount).ceil();
        const spacing = 8.0;
        final mainAxisExtent = width >= 820 ? 58.0 : 52.0;
        final height = rows * mainAxisExtent + (rows - 1) * spacing + 16;

        return SizedBox(
          height: height,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: commands.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: mainAxisExtent,
            ),
            itemBuilder: (context, index) {
              final cmd = commands[index];
              return Material(
                color: accent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _handleCommandTap(cmd),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (cmd.icon != null) ...[
                          Icon(cmd.icon, size: 16, color: iconColor),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            cmd.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: width >= 820 ? 11 : 10,
                              fontWeight: FontWeight.w600,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildKey(ExtraKey key, ThemeData theme, {double fontSize = 12}) {
    final isPressed = (key.label == ExtraKeyIds.ctrl && _ctrlPressed) ||
        (key.label == ExtraKeyIds.alt && _altPressed);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color:
              isPressed ? theme.colorScheme.primary : theme.colorScheme.surface,
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
                        ExtraKeys.localizedLabel(context, key.label),
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
