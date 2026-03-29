import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AI 命令建议卡片
/// 显示在终端和输入栏之间，提供 Run / Copy / Dismiss 操作
class AiCommandSuggestion extends StatelessWidget {
  final String command;
  final String? explanation;
  final VoidCallback onRun;
  final VoidCallback onDismiss;
  final VoidCallback? onRefine;

  const AiCommandSuggestion({
    super.key,
    required this.command,
    this.explanation,
    required this.onRun,
    required this.onDismiss,
    this.onRefine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  command,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (explanation != null && explanation!.isNotEmpty)
                  Text(
                    explanation!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Run
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            tooltip: 'Run',
            visualDensity: VisualDensity.compact,
            onPressed: onRun,
            color: theme.colorScheme.primary,
          ),
          // Copy
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Dismiss
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
