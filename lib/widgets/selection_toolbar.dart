import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/terminal.dart';
import '../core/terminal_controller.dart';
import 'package:xterm/xterm.dart' hide TerminalController;
import '../l10n/app_localizations.dart';

/// Floating toolbar that appears near the text selection in the terminal.
class SelectionToolbar extends StatefulWidget {
  final TermuxTerminal terminal;
  final TermuxTerminalController controller;
  final ScrollController scrollController;
  final TerminalStyle textStyle;
  final Size? cellSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onTextPicker;
  final VoidCallback onMore;
  final VoidCallback onClose;
  final VoidCallback? onViewAsText;

  const SelectionToolbar({
    super.key,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    required this.textStyle,
    this.cellSize,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onCopy,
    required this.onPaste,
    required this.onTextPicker,
    required this.onMore,
    required this.onClose,
    this.onViewAsText,
  });

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    widget.scrollController.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    widget.scrollController.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onUpdate);
      widget.scrollController.addListener(_onUpdate);
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Size _measureCharSize() {
    if (widget.cellSize != null) return widget.cellSize!;
    final style = TextStyle(
      fontFamily: widget.textStyle.fontFamily,
      fontSize: widget.textStyle.fontSize,
      height: widget.textStyle.height,
    );
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return Size(painter.width, painter.height);
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection;
    if (selection == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final charSize = _measureCharSize();
        final double scrollOffset = widget.scrollController.hasClients
            ? widget.scrollController.offset
            : 0.0;
        final int firstVisibleRow = (scrollOffset / charSize.height).floor();

        final begin = selection.begin;
        final end = selection.end;

        // Calculate midpoint of selection for toolbar placement
        final startVisualRow = begin.y - firstVisibleRow;
        final endVisualRow = end.y - firstVisibleRow;

        final double startY = startVisualRow * charSize.height;
        final double endY = (endVisualRow + 1) * charSize.height;

        // Position toolbar: prefer above selection, fall back to below
        const toolbarHeight = 48.0;
        const toolbarMargin = 8.0;

        final double midX = constraints.maxWidth / 2;
        final double desiredToolbarWidth =
            widget.onViewAsText != null ? 372.0 : 316.0;
        final double availableToolbarWidth =
            math.max(0.0, constraints.maxWidth - 16.0);
        final double toolbarWidth =
            math.min(desiredToolbarWidth, availableToolbarWidth);

        double toolbarTop;
        if (startY > toolbarHeight + toolbarMargin) {
          // Place above selection
          toolbarTop = startY - toolbarHeight - toolbarMargin;
        } else if (endY + toolbarHeight + toolbarMargin <
            constraints.maxHeight) {
          // Place below selection
          toolbarTop = endY + toolbarMargin;
        } else {
          // Place at top as fallback
          toolbarTop = toolbarMargin;
        }

        // Ensure toolbar stays in bounds
        final maxToolbarTop =
            math.max(0.0, constraints.maxHeight - toolbarHeight);
        toolbarTop = toolbarTop.clamp(0.0, maxToolbarTop);

        // Calculate toolbar width to center it
        final maxToolbarLeft =
            math.max(8.0, constraints.maxWidth - toolbarWidth - 8.0);
        final toolbarLeft =
            (midX - toolbarWidth / 2).clamp(8.0, maxToolbarLeft);

        return Stack(
          children: [
            Positioned(
              left: toolbarLeft,
              top: toolbarTop,
              child: _ToolbarContent(
                maxWidth: toolbarWidth,
                backgroundColor: widget.backgroundColor,
                foregroundColor: widget.foregroundColor,
                onCopy: widget.onCopy,
                onPaste: widget.onPaste,
                onTextPicker: widget.onTextPicker,
                onMore: widget.onMore,
                onClose: widget.onClose,
                onViewAsText: widget.onViewAsText,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ToolbarContent extends StatelessWidget {
  final double maxWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onTextPicker;
  final VoidCallback onMore;
  final VoidCallback onClose;
  final VoidCallback? onViewAsText;

  const _ToolbarContent({
    required this.maxWidth,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onCopy,
    required this.onPaste,
    required this.onTextPicker,
    required this.onMore,
    required this.onClose,
    this.onViewAsText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: _blendColor(backgroundColor, foregroundColor, 0.12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.copy_rounded,
                label: l10n.copy,
                foregroundColor: foregroundColor,
                onTap: onCopy,
              ),
              _verticalDivider(foregroundColor),
              _ToolbarButton(
                icon: Icons.content_paste_rounded,
                label: l10n.paste,
                foregroundColor: foregroundColor,
                onTap: onPaste,
              ),
              _verticalDivider(foregroundColor),
              _ToolbarButton(
                icon: Icons.auto_awesome,
                label: 'Picker',
                foregroundColor: foregroundColor,
                onTap: onTextPicker,
              ),
              if (onViewAsText != null) ...[
                _verticalDivider(foregroundColor),
                _ToolbarButton(
                  icon: Icons.article_outlined,
                  label: 'View',
                  foregroundColor: foregroundColor,
                  onTap: onViewAsText!,
                ),
              ],
              _verticalDivider(foregroundColor),
              _ToolbarButton(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                foregroundColor: foregroundColor,
                onTap: onMore,
              ),
              _verticalDivider(foregroundColor),
              _ToolbarIconButton(
                icon: Icons.close_rounded,
                foregroundColor: foregroundColor,
                onTap: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verticalDivider(Color color) {
    return Container(
      width: 1,
      height: 24,
      color: color.withValues(alpha: 0.15),
    );
  }

  static Color _blendColor(Color base, Color blend, double amount) {
    return Color.lerp(base, blend, amount) ?? base;
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: foregroundColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child:
            Icon(icon, size: 18, color: foregroundColor.withValues(alpha: 0.6)),
      ),
    );
  }
}
