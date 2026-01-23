import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
// 使用修改版 Terminal，支持 Termux 兼容的 wcwidth
import '../core/terminal.dart';

import 'scaled_terminal_painter.dart';

/// 自定义终端视图，使用 ScaledTerminalPainter 实现字体宽度自动缩放
///
/// 这个组件基于 xterm 的 TerminalView，但使用自定义的绘制器来解决
/// Nerd Font 图标宽度不正确的问题。
class ScaledTerminalView extends StatefulWidget {
  const ScaledTerminalView(
    this.terminal, {
    super.key,
    this.controller,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.textScaler,
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.mouseCursor = SystemMouseCursors.text,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.alwaysShowCursor = false,
    this.deleteDetection = false,
    this.shortcuts,
    this.onKeyEvent,
    this.readOnly = false,
    this.hardwareKeyboardOnly = false,
    this.simulateScroll = true,
  });

  final TermuxTerminal terminal;
  final TerminalController? controller;
  final TerminalTheme theme;
  final TerminalStyle textStyle;
  final TextScaler? textScaler;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final bool autoResize;
  final double backgroundOpacity;
  final FocusNode? focusNode;
  final bool autofocus;
  final void Function(TapUpDetails, CellOffset)? onTapUp;
  final void Function(TapDownDetails, CellOffset)? onSecondaryTapDown;
  final void Function(TapUpDetails, CellOffset)? onSecondaryTapUp;
  final MouseCursor mouseCursor;
  final TextInputType keyboardType;
  final Brightness keyboardAppearance;
  final TerminalCursorType cursorType;
  final bool alwaysShowCursor;
  final bool deleteDetection;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool readOnly;
  final bool hardwareKeyboardOnly;
  final bool simulateScroll;

  @override
  State<ScaledTerminalView> createState() => ScaledTerminalViewState();
}

class ScaledTerminalViewState extends State<ScaledTerminalView> {
  late FocusNode _focusNode;
  late TerminalController _controller;
  late ScrollController _scrollController;

  final _viewportKey = GlobalKey();
  final _scrollableKey = GlobalKey<ScrollableState>();
  final _textInputKey = GlobalKey<_TerminalTextInputState>();

  _ScaledRenderTerminal get _renderTerminal =>
      _viewportKey.currentContext!.findRenderObject() as _ScaledRenderTerminal;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TerminalController();
    _scrollController = widget.scrollController ?? ScrollController();
    super.initState();
  }

  @override
  void didUpdateWidget(ScaledTerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TerminalController();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? ScrollController();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Scrollable(
      key: _scrollableKey,
      controller: _scrollController,
      viewportBuilder: (context, offset) {
        return _ScaledTerminalViewport(
          key: _viewportKey,
          terminal: widget.terminal,
          controller: _controller,
          offset: offset,
          padding: MediaQuery.of(context).padding,
          autoResize: widget.autoResize,
          textStyle: widget.textStyle,
          textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
          theme: widget.theme,
          focusNode: _focusNode,
          cursorType: widget.cursorType,
          alwaysShowCursor: widget.alwaysShowCursor,
        );
      },
    );

    // 手势处理
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (_controller.selection != null) {
          _controller.clearSelection();
        } else if (!widget.hardwareKeyboardOnly) {
          requestKeyboard();
        }
      },
      onTapUp: widget.onTapUp != null
          ? (details) {
              final offset =
                  _renderTerminal.getCellOffset(details.localPosition);
              widget.onTapUp?.call(details, offset);
            }
          : null,
      onSecondaryTapDown: widget.onSecondaryTapDown != null
          ? (details) {
              final offset =
                  _renderTerminal.getCellOffset(details.localPosition);
              widget.onSecondaryTapDown?.call(details, offset);
            }
          : null,
      onSecondaryTapUp: widget.onSecondaryTapUp != null
          ? (details) {
              final offset =
                  _renderTerminal.getCellOffset(details.localPosition);
              widget.onSecondaryTapUp?.call(details, offset);
            }
          : null,
      child: child,
    );

    // 键盘输入处理
    if (!widget.hardwareKeyboardOnly && !widget.readOnly) {
      child = _TerminalTextInput(
        key: _textInputKey,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        inputType: widget.keyboardType,
        keyboardAppearance: widget.keyboardAppearance,
        deleteDetection: widget.deleteDetection,
        onInsert: _onInsert,
        onDelete: () {
          _scrollToBottom();
          widget.terminal.keyInput(TerminalKey.backspace);
        },
        onKeyEvent: _handleKeyEvent,
        readOnly: widget.readOnly,
        child: child,
      );
    } else if (!widget.readOnly) {
      child = Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _handleKeyEvent,
        child: child,
      );
    }

    child = MouseRegion(
      cursor: widget.mouseCursor,
      child: child,
    );

    child = Container(
      color: widget.theme.background.withOpacity(widget.backgroundOpacity),
      padding: widget.padding,
      child: child,
    );

    return child;
  }

  void _onInsert(String text) {
    final key = _charToTerminalKey(text.trim());

    final consumed = key == null ? false : widget.terminal.keyInput(key);

    if (!consumed) {
      widget.terminal.textInput(text);
    }

    _scrollToBottom();
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    final resultOverride = widget.onKeyEvent?.call(focusNode, event);
    if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
      return resultOverride;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = _keyToTerminalKey(event.logicalKey);
    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = widget.terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );

    if (handled) {
      _scrollToBottom();
    }

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _scrollToBottom() {
    final position = _scrollableKey.currentState?.position;
    if (position != null) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  void requestKeyboard() {
    _textInputKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _textInputKey.currentState?.closeKeyboard();
  }

  bool get hasInputConnection =>
      _textInputKey.currentState?.hasInputConnection ?? false;

  double get lineHeight => _renderTerminal.lineHeight;

  Size get cellSize => _renderTerminal.cellSize;
}

/// 终端文本输入处理组件 - 实现 TextInputClient 以连接软键盘
class _TerminalTextInput extends StatefulWidget {
  const _TerminalTextInput({
    super.key,
    required this.child,
    required this.onInsert,
    required this.onDelete,
    required this.onKeyEvent,
    required this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.inputType = TextInputType.text,
    this.keyboardAppearance = Brightness.light,
    this.deleteDetection = false,
  });

  final Widget child;
  final void Function(String) onInsert;
  final void Function() onDelete;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final FocusNode focusNode;
  final bool autofocus;
  final bool readOnly;
  final TextInputType inputType;
  final Brightness keyboardAppearance;
  final bool deleteDetection;

  @override
  _TerminalTextInputState createState() => _TerminalTextInputState();
}

class _TerminalTextInputState extends State<_TerminalTextInput>
    with TextInputClient {
  TextInputConnection? _connection;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

  @override
  void didUpdateWidget(_TerminalTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (!_shouldCreateInputConnection) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        _openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _closeInputConnectionIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }

  bool get hasInputConnection => _connection != null && _connection!.attached;

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void closeKeyboard() {
    if (hasInputConnection) {
      _connection?.close();
    }
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (_currentEditingState.composing.isCollapsed) {
      return widget.onKeyEvent(focusNode, event);
    }
    return KeyEventResult.skipRemainingHandlers;
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (hasInputConnection) {
      _connection!.show();
    } else {
      final config = TextInputConfiguration(
        inputType: widget.inputType,
        inputAction: TextInputAction.newline,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
      );

      _connection = TextInput.attach(this, config);
      _connection!.show();
      _connection!.setEditingState(_initEditingState);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_connection != null && _connection!.attached) {
      _connection!.close();
      _connection = null;
    }
  }

  TextEditingValue get _initEditingState => widget.deleteDetection
      ? const TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        )
      : const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );

  late var _currentEditingState = _initEditingState.copyWith();

  @override
  TextEditingValue? get currentTextEditingValue {
    return _currentEditingState;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null;
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _currentEditingState = value;

    // 处理 IME 输入中的组合文本
    if (!_currentEditingState.composing.isCollapsed) {
      return;
    }

    if (_currentEditingState.text.length < _initEditingState.text.length) {
      widget.onDelete();
    } else {
      final textDelta = _currentEditingState.text.substring(
        _initEditingState.text.length,
      );

      if (textDelta.isNotEmpty) {
        widget.onInsert(textDelta);
      }
    }

    // 重置编辑状态
    if (_currentEditingState.composing.isCollapsed &&
        _currentEditingState.text != _initEditingState.text) {
      _connection!.setEditingState(_initEditingState);
    }
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline ||
        action == TextInputAction.done) {
      widget.onInsert('\r');
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showToolbar() {}
}

/// 内部视口组件
class _ScaledTerminalViewport extends LeafRenderObjectWidget {
  const _ScaledTerminalViewport({
    super.key,
    required this.terminal,
    required this.controller,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.textStyle,
    required this.textScaler,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.alwaysShowCursor,
  });

  final TermuxTerminal terminal;
  final TerminalController controller;
  final ViewportOffset offset;
  final EdgeInsets padding;
  final bool autoResize;
  final TerminalStyle textStyle;
  final TextScaler textScaler;
  final TerminalTheme theme;
  final FocusNode focusNode;
  final TerminalCursorType cursorType;
  final bool alwaysShowCursor;

  @override
  _ScaledRenderTerminal createRenderObject(BuildContext context) {
    return _ScaledRenderTerminal(
      terminal: terminal,
      controller: controller,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      textStyle: textStyle,
      textScaler: textScaler,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      alwaysShowCursor: alwaysShowCursor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _ScaledRenderTerminal renderObject) {
    renderObject
      ..terminal = terminal
      ..controller = controller
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..textStyle = textStyle
      ..textScaler = textScaler
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..alwaysShowCursor = alwaysShowCursor;
  }
}

/// 自定义渲染器，使用 ScaledTerminalPainter
class _ScaledRenderTerminal extends RenderBox
    with RelayoutWhenSystemFontsChangeMixin {
  _ScaledRenderTerminal({
    required TermuxTerminal terminal,
    required TerminalController controller,
    required ViewportOffset offset,
    required EdgeInsets padding,
    required bool autoResize,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    required TerminalTheme theme,
    required FocusNode focusNode,
    required TerminalCursorType cursorType,
    required bool alwaysShowCursor,
  })  : _terminal = terminal,
        _controller = controller,
        _offset = offset,
        _padding = padding,
        _autoResize = autoResize,
        _focusNode = focusNode,
        _cursorType = cursorType,
        _alwaysShowCursor = alwaysShowCursor,
        _painter = ScaledTerminalPainter(
          theme: theme,
          textStyle: textStyle,
          textScaler: textScaler,
        );

  TermuxTerminal _terminal;
  set terminal(TermuxTerminal terminal) {
    if (_terminal == terminal) return;
    if (attached) _terminal.removeListener(_onTerminalChange);
    _terminal = terminal;
    if (attached) _terminal.addListener(_onTerminalChange);
    _resizeTerminalIfNeeded();
    markNeedsLayout();
  }

  TerminalController _controller;
  set controller(TerminalController controller) {
    if (_controller == controller) return;
    if (attached) _controller.removeListener(_onControllerUpdate);
    _controller = controller;
    if (attached) _controller.addListener(_onControllerUpdate);
    markNeedsLayout();
  }

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _autoResize;
  set autoResize(bool value) {
    if (value == _autoResize) return;
    _autoResize = value;
    markNeedsLayout();
  }

  set textStyle(TerminalStyle value) {
    if (value == _painter.textStyle) return;
    _painter.textStyle = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (value == _painter.textScaler) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set theme(TerminalTheme value) {
    if (value == _painter.theme) return;
    _painter.theme = value;
    markNeedsPaint();
  }

  FocusNode _focusNode;
  set focusNode(FocusNode value) {
    if (value == _focusNode) return;
    if (attached) _focusNode.removeListener(_onFocusChange);
    _focusNode = value;
    if (attached) _focusNode.addListener(_onFocusChange);
    markNeedsPaint();
  }

  TerminalCursorType _cursorType;
  set cursorType(TerminalCursorType value) {
    if (value == _cursorType) return;
    _cursorType = value;
    markNeedsPaint();
  }

  bool _alwaysShowCursor;
  set alwaysShowCursor(bool value) {
    if (value == _alwaysShowCursor) return;
    _alwaysShowCursor = value;
    markNeedsPaint();
  }

  _TerminalSize? _viewportSize;

  final ScaledTerminalPainter _painter;

  var _stickToBottom = true;

  void _onScroll() {
    _stickToBottom = _scrollOffset >= _maxScrollExtent;
    markNeedsLayout();
  }

  void _onFocusChange() {
    markNeedsPaint();
  }

  void _onTerminalChange() {
    markNeedsLayout();
  }

  void _onControllerUpdate() {
    markNeedsLayout();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_onScroll);
    _terminal.addListener(_onTerminalChange);
    _controller.addListener(_onControllerUpdate);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void detach() {
    super.detach();
    _offset.removeListener(_onScroll);
    _terminal.removeListener(_onTerminalChange);
    _controller.removeListener(_onControllerUpdate);
    _focusNode.removeListener(_onFocusChange);
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void systemFontsDidChange() {
    _painter.clearFontCache();
    super.systemFontsDidChange();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    _updateViewportSize();
    _updateScrollOffset();

    if (_stickToBottom) {
      _offset.correctBy(_maxScrollExtent - _scrollOffset);
    }
  }

  double get _terminalHeight =>
      _terminal.buffer.lines.length * _painter.cellSize.height;

  double get _scrollOffset => _offset.pixels;

  double get lineHeight => _painter.cellSize.height;

  Size get cellSize => _painter.cellSize;

  CellOffset getCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top + _scrollOffset;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.buffer.lines.length - 1),
    );
  }

  void _updateViewportSize() {
    if (size <= _painter.cellSize) {
      return;
    }

    final viewportSize = _TerminalSize(
      size.width ~/ _painter.cellSize.width,
      _viewportHeight ~/ _painter.cellSize.height,
    );

    if (_viewportSize != viewportSize) {
      _viewportSize = viewportSize;
      _resizeTerminalIfNeeded();
    }
  }

  void _resizeTerminalIfNeeded() {
    if (_autoResize && _viewportSize != null) {
      _terminal.resize(
        _viewportSize!.width,
        _viewportSize!.height,
        _painter.cellSize.width.round(),
        _painter.cellSize.height.round(),
      );
    }
  }

  void _updateScrollOffset() {
    _offset.applyViewportDimension(_viewportHeight);
    _offset.applyContentDimensions(0, _maxScrollExtent);
  }

  bool get _shouldShowCursor {
    return _terminal.cursorVisibleMode || _alwaysShowCursor;
  }

  double get _viewportHeight {
    return size.height - _padding.vertical;
  }

  double get _maxScrollExtent {
    return max(_terminalHeight - _viewportHeight, 0.0);
  }

  double get _lineOffset {
    return -_scrollOffset + _padding.top;
  }

  Offset get cursorOffset {
    return Offset(
      _terminal.buffer.cursorX * _painter.cellSize.width,
      _terminal.buffer.absoluteCursorY * _painter.cellSize.height + _lineOffset,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final lines = _terminal.buffer.lines;
    final charHeight = _painter.cellSize.height;

    final firstLineOffset = _scrollOffset - _padding.top;
    final lastLineOffset = _scrollOffset + size.height + _padding.bottom;

    final firstLine = firstLineOffset ~/ charHeight;
    final lastLine = lastLineOffset ~/ charHeight;

    final effectFirstLine = firstLine.clamp(0, lines.length - 1);
    final effectLastLine = lastLine.clamp(0, lines.length - 1);

    for (var i = effectFirstLine; i <= effectLastLine; i++) {
      _painter.paintLine(
        canvas,
        offset.translate(0, (i * charHeight + _lineOffset).truncateToDouble()),
        lines[i],
      );
    }

    if (_terminal.buffer.absoluteCursorY >= effectFirstLine &&
        _terminal.buffer.absoluteCursorY <= effectLastLine) {
      if (_shouldShowCursor) {
        _painter.paintCursor(
          canvas,
          offset + cursorOffset,
          cursorType: _cursorType,
          hasFocus: _focusNode.hasFocus,
        );
      }
    }

    // Paint selection
    if (_controller.selection != null) {
      _paintSelection(
        canvas,
        _controller.selection!,
        effectFirstLine,
        effectLastLine,
      );
    }

    context.setWillChangeHint();
  }

  void _paintSelection(
    Canvas canvas,
    BufferRange selection,
    int firstLine,
    int lastLine,
  ) {
    for (final segment in selection.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      final start = segment.start ?? 0;
      final end = segment.end ?? _terminal.viewWidth;

      final startOffset = Offset(
        start * _painter.cellSize.width,
        segment.line * _painter.cellSize.height + _lineOffset,
      );

      _painter.paintHighlight(
          canvas, startOffset, end - start, _painter.theme.selection);
    }
  }
}

/// 终端尺寸
class _TerminalSize {
  final int width;
  final int height;

  _TerminalSize(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TerminalSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// 键盘映射表
final _keyMapping = <LogicalKeyboardKey, TerminalKey>{
  LogicalKeyboardKey.enter: TerminalKey.enter,
  LogicalKeyboardKey.escape: TerminalKey.escape,
  LogicalKeyboardKey.backspace: TerminalKey.backspace,
  LogicalKeyboardKey.tab: TerminalKey.tab,
  LogicalKeyboardKey.arrowUp: TerminalKey.arrowUp,
  LogicalKeyboardKey.arrowDown: TerminalKey.arrowDown,
  LogicalKeyboardKey.arrowLeft: TerminalKey.arrowLeft,
  LogicalKeyboardKey.arrowRight: TerminalKey.arrowRight,
  LogicalKeyboardKey.insert: TerminalKey.insert,
  LogicalKeyboardKey.delete: TerminalKey.delete,
  LogicalKeyboardKey.home: TerminalKey.home,
  LogicalKeyboardKey.end: TerminalKey.end,
  LogicalKeyboardKey.pageUp: TerminalKey.pageUp,
  LogicalKeyboardKey.pageDown: TerminalKey.pageDown,
  LogicalKeyboardKey.f1: TerminalKey.f1,
  LogicalKeyboardKey.f2: TerminalKey.f2,
  LogicalKeyboardKey.f3: TerminalKey.f3,
  LogicalKeyboardKey.f4: TerminalKey.f4,
  LogicalKeyboardKey.f5: TerminalKey.f5,
  LogicalKeyboardKey.f6: TerminalKey.f6,
  LogicalKeyboardKey.f7: TerminalKey.f7,
  LogicalKeyboardKey.f8: TerminalKey.f8,
  LogicalKeyboardKey.f9: TerminalKey.f9,
  LogicalKeyboardKey.f10: TerminalKey.f10,
  LogicalKeyboardKey.f11: TerminalKey.f11,
  LogicalKeyboardKey.f12: TerminalKey.f12,
};

/// 键盘映射辅助函数
TerminalKey? _keyToTerminalKey(LogicalKeyboardKey key) {
  return _keyMapping[key];
}

/// 字符到终端键的映射
TerminalKey? _charToTerminalKey(String char) {
  if (char.isEmpty) return null;
  switch (char) {
    case '\n':
    case '\r':
      return TerminalKey.enter;
    case '\t':
      return TerminalKey.tab;
    case '\x7f':
    case '\b':
      return TerminalKey.backspace;
    case '\x1b':
      return TerminalKey.escape;
    default:
      return null;
  }
}
