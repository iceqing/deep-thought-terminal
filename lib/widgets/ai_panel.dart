import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import 'ai_chat_bubble.dart';

/// AI 侧边面板
/// 从右侧滑入，支持 Chat 模式
class AiPanel extends StatefulWidget {
  final double width;
  final VoidCallback onClose;
  final void Function(String command)? onRunCommand;
  final String? currentCwd;
  final String? currentShell;

  const AiPanel({
    super.key,
    required this.width,
    required this.onClose,
    this.onRunCommand,
    this.currentCwd,
    this.currentShell,
  });

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<AiProvider>();
    provider.sendMessage(
      text,
      cwd: widget.currentCwd,
      shellType: widget.currentShell,
    );
    _inputController.clear();

    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(theme, aiProvider),

          // Chat area
          Expanded(
            child: aiProvider.chatHistory.isEmpty
                ? _buildEmptyState(theme)
                : _buildChatList(aiProvider),
          ),

          // Input area
          _buildInputArea(theme, aiProvider),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AiProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: title + action buttons
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Text('AI', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (aiProvider.isStreaming)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  tooltip: 'Stop',
                  visualDensity: VisualDensity.compact,
                  onPressed: aiProvider.cancelStreaming,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear chat',
                visualDensity: VisualDensity.compact,
                onPressed: aiProvider.chatHistory.isEmpty
                    ? null
                    : () => aiProvider.clearHistory(),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
              ),
            ],
          ),
          // Mode selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AiMode>(
              segments: const [
                ButtonSegment(
                  value: AiMode.chat,
                  icon: Icon(Icons.chat_bubble_outline, size: 14),
                  label: Text('Chat'),
                ),
                ButtonSegment(
                  value: AiMode.agent,
                  icon: Icon(Icons.smart_toy_outlined, size: 14),
                  label: Text('Agent'),
                ),
                ButtonSegment(
                  value: AiMode.plan,
                  icon: Icon(Icons.route_outlined, size: 14),
                  label: Text('Plan'),
                ),
              ],
              selected: {aiProvider.currentMode},
              onSelectionChanged: (selected) {
                aiProvider.setMode(selected.first);
              },
              style: SegmentedButton.styleFrom(
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
                textStyle: const TextStyle(fontSize: 11),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final aiProvider = context.watch<AiProvider>();
    final mode = aiProvider.currentMode;

    final (icon, title, desc, chips) = switch (mode) {
      AiMode.chat => (
          Icons.auto_awesome_outlined,
          'Chat Mode',
          'Ask me anything about shell commands.\nI can help generate, explain, and debug commands.',
          ['List all files', 'Show disk usage', 'Find large files'],
        ),
      AiMode.agent => (
          Icons.smart_toy_outlined,
          'Agent Mode',
          'Tell me a goal and I\'ll execute commands\nstep by step to accomplish it.',
          [
            'Set up a git repo',
            'Install and configure nginx',
            'Clean up temp files'
          ],
        ),
      AiMode.plan => (
          Icons.route_outlined,
          'Plan Mode',
          'Describe what you want to do and I\'ll create\na step-by-step plan before executing.',
          ['Deploy this project', 'Migrate database', 'Set up CI/CD'],
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children:
                  chips.map((c) => _buildSuggestionChip(theme, c)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(ThemeData theme, String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _inputController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildChatList(AiProvider aiProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: aiProvider.chatHistory.length,
      itemBuilder: (context, index) {
        final message = aiProvider.chatHistory[index];
        if (message.role == AiMessageRole.system &&
            message.type != AiMessageType.commandSuggestion) {
          return const SizedBox.shrink();
        }
        return AiChatBubble(
          message: message,
          onRunCommand: message.suggestedCommand != null
              ? () => widget.onRunCommand?.call(message.suggestedCommand!)
              : null,
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme, AiProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !aiProvider.isStreaming,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: switch (aiProvider.currentMode) {
                  AiMode.chat => 'Ask AI...',
                  AiMode.agent => 'Describe a goal...',
                  AiMode.plan => 'What do you want to plan?',
                },
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: aiProvider.isStreaming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: aiProvider.isStreaming ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
