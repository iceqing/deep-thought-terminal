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
    const modes = AiMode.values;
    final next = modes[(aiProvider.currentMode.index + 1) % modes.length];
    aiProvider.setMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();
    final mode = aiProvider.currentMode;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final barHeight = isMobile ? 52.0 : 44.0;
    final actionSize = isMobile ? 40.0 : 32.0;

    return Container(
      height: barHeight,
      margin: EdgeInsets.fromLTRB(10, isMobile ? 6 : 2, 10, isMobile ? 6 : 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(barHeight / 2),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: isMobile ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mode indicator (tap to cycle)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _cycleMode(aiProvider),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 8,
                vertical: isMobile ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _modeIcons[mode],
                    size: isMobile ? 16 : 14,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modeLabels[mode]!,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 11,
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
                hintStyle: TextStyle(fontSize: isMobile ? 14 : 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 4,
                  vertical: isMobile ? 14 : 10,
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: isMobile ? 14 : 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (_hasText) widget.onSubmit();
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: SizedBox(
              key: ValueKey(_hasText),
              width: actionSize,
              height: actionSize,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _hasText ? widget.onSubmit : widget.onTapOpenPanel,
                child: Icon(
                  _hasText ? Icons.send_rounded : Icons.fullscreen_rounded,
                  size: isMobile ? 20 : 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
