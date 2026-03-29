import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_chat_message.dart';

/// AI 聊天气泡组件
/// 支持流式渲染、思考过程展示和不同类型的消息展示
class AiChatBubble extends StatelessWidget {
  final AiChatMessage message;
  final VoidCallback? onRunCommand;
  final VoidCallback? onReuseMessage;

  const AiChatBubble({
    super.key,
    required this.message,
    this.onRunCommand,
    this.onReuseMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AiMessageRole.user;
    final isSystemResult = message.role == AiMessageRole.system;

    if (isSystemResult) {
      return _buildCommandResultBubble(theme);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(theme),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Thinking block (collapsible)
                if (!isUser &&
                    message.thinking != null &&
                    message.thinking!.isNotEmpty)
                  _ThinkingBlock(
                    thinking: message.thinking!,
                    isStreaming: message.isStreaming && message.content.isEmpty,
                  ),
                _buildBubble(theme, isUser, message.error != null),
                if (message.suggestedCommand != null) ...[
                  const SizedBox(height: 4),
                  _buildCommandCard(theme),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(theme),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final isUser = message.role == AiMessageRole.user;
    return CircleAvatar(
      radius: 14,
      backgroundColor:
          isUser ? theme.colorScheme.primary : theme.colorScheme.tertiary,
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 16,
        color:
            isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onTertiary,
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, bool isUser, bool isError) {
    final colorScheme = theme.colorScheme;
    final typeLabel = _typeLabel(message.type);
    final bgColor = isUser
        ? colorScheme.primary
        : isError
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh;
    final fgColor = isUser
        ? colorScheme.onPrimary
        : isError
            ? colorScheme.onErrorContainer
            : colorScheme.onSurface;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 12 : 4),
          topRight: Radius.circular(isUser ? 4 : 12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          if (typeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fgColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: fgColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

          // Content
          SelectableText(
            message.content.isEmpty && message.isStreaming
                ? '...'
                : message.content,
            style: TextStyle(
              color: fgColor,
              fontSize: 14,
              fontFamily: message.type == AiMessageType.commandSuggestion
                  ? 'monospace'
                  : null,
            ),
          ),

          // Streaming indicator
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fgColor.withValues(alpha: 0.5),
                ),
              ),
            ),

          // Error message
          if (isError)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.error!,
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),

          // Action buttons
          if (message.content.isNotEmpty && !message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                    },
                  ),
                  if (isUser && onReuseMessage != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Reuse',
                      visualDensity: VisualDensity.compact,
                      onPressed: onReuseMessage,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 命令执行结果气泡（system role）
  Widget _buildCommandResultBubble(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: _CommandResultBubble(content: message.content),
    );
  }

  Widget _buildCommandCard(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.suggestedCommand!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonalIcon(
                onPressed: onRunCommand,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Run'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy command',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: message.suggestedCommand!));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(AiMessageType type) {
    switch (type) {
      case AiMessageType.chat:
        return '';
      case AiMessageType.commandSuggestion:
        return 'Command';
      case AiMessageType.errorDiagnosis:
        return 'Diagnosis';
      case AiMessageType.explanation:
        return 'Explanation';
      case AiMessageType.agent:
        return '';
    }
  }
}

class _CommandResultBubble extends StatefulWidget {
  final String content;

  const _CommandResultBubble({required this.content});

  @override
  State<_CommandResultBubble> createState() => _CommandResultBubbleState();
}

class _CommandResultBubbleState extends State<_CommandResultBubble> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _shouldStartExpanded(widget.content);
  }

  @override
  void didUpdateWidget(covariant _CommandResultBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _expanded = _shouldStartExpanded(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parsed = _parseCommandResult(widget.content);
    final outputLines = '\n'.allMatches(parsed.output).length + 1;
    final canCollapse = parsed.output.trim().isNotEmpty && outputLines > 3;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      margin: const EdgeInsets.only(left: 36),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal,
                  size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Command Output',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy command',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: parsed.command));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              parsed.command,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (parsed.output.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: canCollapse
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Output',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$outputLines lines',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (canCollapse)
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  parsed.output,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldStartExpanded(String content) {
    final parsed = _parseCommandResult(content);
    final outputLines = '\n'.allMatches(parsed.output).length + 1;
    return outputLines <= 8;
  }

  _ParsedCommandResult _parseCommandResult(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty) {
      return const _ParsedCommandResult(
          command: '(unknown command)', output: '');
    }

    final firstLine = lines.first.trimRight();
    final remaining = lines.skip(1).join('\n').trimRight();
    if (firstLine.startsWith(r'$ ')) {
      return _ParsedCommandResult(command: firstLine, output: remaining);
    }
    if (firstLine.contains(': ')) {
      return _ParsedCommandResult(command: firstLine, output: remaining);
    }
    return _ParsedCommandResult(
        command: '(output only)', output: raw.trimRight());
  }
}

class _ParsedCommandResult {
  final String command;
  final String output;

  const _ParsedCommandResult({
    required this.command,
    required this.output,
  });
}

/// 可折叠的思考过程区块，参考 Claude Code 风格
class _ThinkingBlock extends StatefulWidget {
  final String thinking;
  final bool isStreaming;

  const _ThinkingBlock({
    required this.thinking,
    required this.isStreaming,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (always visible, tap to toggle)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isStreaming)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colorScheme.tertiary,
                      ),
                    )
                  else
                    Icon(
                      Icons.psychology,
                      size: 14,
                      color: colorScheme.tertiary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isStreaming ? 'Thinking...' : 'Thinking',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Thinking content (collapsible)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.thinking,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
