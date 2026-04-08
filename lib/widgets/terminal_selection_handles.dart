import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' hide TerminalController;
import 'dart:math' as math;
// 使用修改版 Terminal 和 CellAnchor
import '../core/terminal.dart';
import '../core/terminal_controller.dart';
import '../core/buffer/line.dart' as local;

/// Widget to display selection handles for the terminal
class TerminalSelectionHandles extends StatefulWidget {
  final TermuxTerminal terminal;
  final TermuxTerminalController controller;
  final ScrollController scrollController;
  final TerminalStyle textStyle;
  final Size? cellSize;
  final Color handleColor;
  final VoidCallback? onSelectionChanged;

  const TerminalSelectionHandles({
    super.key,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    required this.textStyle,
    this.cellSize,
    required this.handleColor,
    this.onSelectionChanged,
  });

  @override
  State<TerminalSelectionHandles> createState() =>
      _TerminalSelectionHandlesState();
}

class _TerminalSelectionHandlesState extends State<TerminalSelectionHandles> {
  Size? _charSize;

  @override
  void initState() {
    super.initState();
    // 监听终端变化（内容更新、滚动等）
    widget.terminal.addListener(_onTerminalUpdate);
    // 监听控制器变化（选择范围更新）
    widget.controller.addListener(_onSelectionUpdate);
    // 监听滚动变化
    widget.scrollController.addListener(_onScrollUpdate);
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalUpdate);
    widget.controller.removeListener(_onSelectionUpdate);
    widget.scrollController.removeListener(_onScrollUpdate);
    super.dispose();
  }

  void _onTerminalUpdate() {
    if (mounted) setState(() {});
  }

  void _onSelectionUpdate() {
    if (mounted) setState(() {});
  }

  void _onScrollUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TerminalSelectionHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdate);
      widget.terminal.addListener(_onTerminalUpdate);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionUpdate);
      widget.controller.addListener(_onSelectionUpdate);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollUpdate);
      widget.scrollController.addListener(_onScrollUpdate);
    }
    if (oldWidget.textStyle.fontSize != widget.textStyle.fontSize ||
        oldWidget.textStyle.fontFamily != widget.textStyle.fontFamily) {
      _charSize = null;
    }
  }

  Size _measureCharSize(BuildContext context) {
    if (widget.cellSize != null) return widget.cellSize!;
    if (_charSize != null) return _charSize!;

    final style = TextStyle(
      fontFamily: widget.textStyle.fontFamily,
      fontSize: widget.textStyle.fontSize,
      height: widget.textStyle.height,
    );

    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    _charSize = Size(painter.width, painter.height);
    return _charSize!;
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    if (selection == null) return const SizedBox.shrink();

    final charSize = _measureCharSize(context);

    // Calculate first visible row based on scroll offset
    // Scroll offset is in pixels.
    final double scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;

    final int firstVisibleRow = (scrollOffset / charSize.height).floor();

    final int viewHeight = widget.terminal.viewHeight;

    final CellOffset begin = selection.begin;
    final CellOffset end = selection.end;

    final startVisualRow = begin.y - firstVisibleRow;
    final endVisualRow = end.y - firstVisibleRow;

    final double startX = begin.x * charSize.width;
    final double startY = startVisualRow * charSize.height;

    final double endX = end.x * charSize.width;
    final double endY = endVisualRow * charSize.height;

    final startHandlePos = Offset(startX, startY + charSize.height);
    final endHandlePos = Offset(endX, endY + charSize.height);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Only show if visible in viewport (adding some buffer)
        if (startVisualRow >= -2 && startVisualRow <= viewHeight + 1)
          Positioned(
            left: startHandlePos.dx - 24,
            top: startHandlePos.dy,
            child:
                _buildHandle(isStart: true, charSize: charSize, offset: begin),
          ),

        if (endVisualRow >= -2 && endVisualRow <= viewHeight + 1)
          Positioned(
            left: endHandlePos.dx - 24,
            top: endHandlePos.dy,
            child:
                _buildHandle(isStart: false, charSize: charSize, offset: end),
          ),
      ],
    );
  }

  Widget _buildHandle({
    required bool isStart,
    required Size charSize,
    required CellOffset offset,
  }) {
    // Touch target size
    const double touchSize = 48.0;

    return GestureDetector(
      onPanStart: (_) {
        _accDx = 0;
        _accDy = 0;
      },
      onPanUpdate: (details) {
        _handleDrag(isStart, details, charSize);
      },
      onPanEnd: (_) {
        _accDx = 0;
        _accDy = 0;
      },
      onPanCancel: () {
        _accDx = 0;
        _accDy = 0;
      },
      child: Container(
        width: touchSize,
        height: touchSize,
        color: Colors.transparent,
        child: CustomPaint(
          painter: _HandlePainter(
            color: widget.handleColor,
            isStart: isStart,
          ),
        ),
      ),
    );
  }

  double _accDx = 0;
  double _accDy = 0;

  void _handleDrag(bool isStart, DragUpdateDetails details, Size charSize) {
    _accDx += details.delta.dx;
    _accDy += details.delta.dy;

    int colChange = 0;
    int rowChange = 0;

    if (_accDx.abs() >= charSize.width) {
      colChange = (_accDx / charSize.width).truncate();
      _accDx -= colChange * charSize.width;
    }

    if (_accDy.abs() >= charSize.height) {
      rowChange = (_accDy / charSize.height).truncate();
      _accDy -= rowChange * charSize.height;
    }

    if (colChange == 0 && rowChange == 0) return;

    final selection = widget.controller.selection;
    if (selection == null) return;

    final currentOffset = isStart ? selection.begin : selection.end;

    var newX = currentOffset.x + colChange;
    var newY = currentOffset.y + rowChange;

    // Clamp
    newX = math.max(0, math.min(newX, widget.terminal.viewWidth - 1));
    newY = math.max(0, math.min(newY, widget.terminal.buffer.height - 1));

    // Create new anchor using createAnchorFromOffset
    final newOffset = CellOffset(newX, newY);
    final newAnchor = widget.terminal.buffer.createAnchorFromOffset(newOffset);

    final fixedOffset = isStart ? selection.end : selection.begin;
    final fixedAnchor =
        widget.terminal.buffer.createAnchorFromOffset(fixedOffset);

    // Helper to compare anchors - 使用 local.CellAnchor 类型
    int compare(local.CellAnchor a, local.CellAnchor b) {
      if (a.y != b.y) return a.y.compareTo(b.y);
      return a.x.compareTo(b.x);
    }

    if (isStart) {
      if (compare(newAnchor, fixedAnchor) > 0) {
        widget.controller.setSelection(fixedAnchor, newAnchor);
      } else {
        widget.controller.setSelection(newAnchor, fixedAnchor);
      }
    } else {
      if (compare(newAnchor, fixedAnchor) < 0) {
        widget.controller.setSelection(newAnchor, fixedAnchor);
      } else {
        widget.controller.setSelection(fixedAnchor, newAnchor);
      }
    }

    widget.onSelectionChanged?.call();

    // Force rebuild to update handle positions immediately
    setState(() {});
  }
}

class _HandlePainter extends CustomPainter {
  final Color color;
  final bool isStart;

  _HandlePainter({required this.color, required this.isStart});

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制主体颜色
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    const radius = 12.0;

    if (isStart) {
      final bulbCenter = Offset(centerX - radius + 1, radius);

      // 绘制圆形
      canvas.drawCircle(bulbCenter, radius, paint);

      // 绘制连接矩形
      final rect = Rect.fromLTRB(bulbCenter.dx, 0, centerX, bulbCenter.dy);
      canvas.drawRect(rect, paint);
    } else {
      final bulbCenter = Offset(centerX + radius - 1, radius);

      // 绘制圆形
      canvas.drawCircle(bulbCenter, radius, paint);

      // 绘制连接矩形
      final rect = Rect.fromLTRB(centerX, 0, bulbCenter.dx, bulbCenter.dy);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isStart != isStart;
  }
}
