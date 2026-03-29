import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';

/// AI 底部快捷输入栏
/// 位于终端和 Extra Keys 之间，用于快速输入 `??` 命令
class AiInlineBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onTapOpenPanel;
  final bool enabled;

  const AiInlineBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.onTapOpenPanel,
    this.enabled = true,
  });

  @override
  State<AiInlineBar> createState() => _AiInlineBarState();
}

class _AiInlineBarState extends State<AiInlineBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }

  void _updateHasText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  static const _modeIcons = {
    AiMode.chat: Icons.chat_bubble_outline,
    AiMode.agent: Icons.smart_toy_outlined,
    AiMode.plan: Icons.route_outlined,
  };

  static const _modeLabels = {
    AiMode.chat: 'Chat',
    AiMode.agent: 'Agent',
    AiMode.plan: 'Plan',
  };

  static const _modeHints = {
    AiMode.chat: 'Ask AI for a command...',
    AiMode.agent: 'Describe a goal...',
    AiMode.plan: 'What to plan?',
  };

  void _cycleMode(AiProvider aiProvider) {
    final modes = AiMode.values;
    final next = modes[(aiProvider.currentMode.index + 1) % modes.length];
    aiProvider.setMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();
    final mode = aiProvider.currentMode;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Mode indicator (tap to cycle)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _cycleMode(aiProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _modeIcons[mode],
                    size: 14,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modeLabels[mode]!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              decoration: InputDecoration(
                hintText: _modeHints[mode],
                hintStyle: const TextStyle(fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (_hasText) widget.onSubmit();
              },
            ),
          ),
          if (_hasText)
            IconButton(
              icon: const Icon(Icons.send, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: widget.onSubmit,
              tooltip: 'Send',
            )
          else
            IconButton(
              icon: const Icon(Icons.open_in_full, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: widget.onTapOpenPanel,
              tooltip: 'Open AI panel',
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
