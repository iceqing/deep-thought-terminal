import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import 'ai_chat_bubble.dart';

/// AI 侧边面板
/// 从右侧滑入，支持 Chat 模式
class AiPanel extends StatefulWidget {
  final double width;
  final bool fullScreen;
  final VoidCallback onClose;
  final void Function(String command)? onRunCommand;
  final String? currentCwd;
  final String? currentShell;
  final String Function(String name, Map<String, dynamic> input)? toolExecutor;

  const AiPanel({
    super.key,
    required this.width,
    this.fullScreen = false,
    required this.onClose,
    this.onRunCommand,
    this.currentCwd,
    this.currentShell,
    this.toolExecutor,
  });

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<AiProvider>();
    final executor = widget.toolExecutor ?? defaultToolExecutor;
    provider.sendMessage(
      text,
      cwd: widget.currentCwd,
      shellType: widget.currentShell,
      toolExecutor: executor,
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

  void _reuseMessage(String text) {
    _inputController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _inputFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();

    return Container(
      width: widget.fullScreen ? double.infinity : widget.width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: widget.fullScreen
            ? null
            : Border(
                left: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
        boxShadow: widget.fullScreen
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ],
      ),
      child: SafeArea(
        top: !widget.fullScreen,
        bottom: true,
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
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AiProvider aiProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, widget.fullScreen ? 8 : 4, 8, 4),
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
          if (widget.fullScreen)
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          // Top row: title + action buttons
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: widget.fullScreen ? 20 : 18,
                  color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'AI Assistant',
                style: widget.fullScreen
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleSmall,
              ),
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
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: aiProvider.chatSessions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final session = aiProvider.chatSessions[index];
                      final selected =
                          session.id == aiProvider.currentSessionId;
                      return InputChip(
                        label: Text(
                          session.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: selected,
                        onPressed: () => aiProvider.switchSession(session.id),
                        onDeleted: aiProvider.chatSessions.length > 1
                            ? () => aiProvider.deleteSession(session.id)
                            : null,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                            const VisualDensity(horizontal: -3, vertical: -3),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  tooltip: 'New chat',
                  visualDensity: VisualDensity.compact,
                  onPressed: aiProvider.isStreaming
                      ? null
                      : () => aiProvider.createSession(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final topPadding = constraints.maxHeight > 520 ? 56.0 : 24.0;
        final contentMaxWidth = widget.fullScreen ? 560.0 : 420.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
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
                    children: chips
                        .map((c) => _buildSuggestionChip(theme, c))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          onReuseMessage: message.role == AiMessageRole.user
              ? () => _reuseMessage(message.content)
              : null,
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme, AiProvider aiProvider) {
    final isAgent = aiProvider.currentMode == AiMode.agent;
    final isPlan = aiProvider.currentMode == AiMode.plan;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, widget.fullScreen ? 12 : 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Agent status bar
          if (isAgent && aiProvider.isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Agent running...',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          // Plan mode buttons
          if (isPlan && aiProvider.isStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route,
                      size: 14, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Plan ready — review and approve',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  enabled: !aiProvider.isStreaming,
                  maxLines: widget.fullScreen ? 6 : 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: switch (aiProvider.currentMode) {
                      AiMode.chat => 'Ask AI...',
                      AiMode.agent => 'Describe a goal...',
                      AiMode.plan => 'What do you want to plan?',
                    },
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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
        ],
      ),
    );
  }
}
