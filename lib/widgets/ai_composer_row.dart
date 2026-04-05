import 'package:flutter/material.dart';

class AiComposerRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String hintText;
  final int minLines;
  final int maxLines;
  final LayerLink? layerLink;
  final VoidCallback onCommandTap;
  final VoidCallback onSubmit;
  final Widget trailing;
  final Color accentColor;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry contentPadding;
  final InputBorder? border;

  const AiComposerRow({
    super.key,
    required this.controller,
    this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.layerLink,
    required this.onCommandTap,
    required this.onSubmit,
    required this.trailing,
    required this.accentColor,
    required this.iconSize,
    required this.fontSize,
    required this.contentPadding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: fontSize),
        border: border ?? InputBorder.none,
        contentPadding: contentPadding,
        isDense: true,
      ),
      style: TextStyle(fontSize: fontSize),
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
    );

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCommandTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.terminal_rounded,
              size: iconSize,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: layerLink == null
              ? field
              : CompositedTransformTarget(link: layerLink!, child: field),
        ),
        const SizedBox(width: 4),
        trailing,
      ],
    );
  }
}
