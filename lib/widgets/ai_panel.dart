import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_config.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import 'ai_chat_bubble.dart';
import 'ai_composer_row.dart';
import 'ai_quick_actions.dart';
import 'provider_icon.dart';

/// AI 侧边面板
/// 从右侧滑入，支持 Chat / Agent / Plan 模式
class AiPanel extends StatefulWidget {
  final double width;
  final bool fullScreen;
  final VoidCallback onClose;
  final void Function(String command)? onRunCommand;
  final TextEditingController? controller;
  final String? currentCwd;
  final String? currentShell;
  final Future<String> Function(String name, Map<String, dynamic> input)? toolExecutor;

  const AiPanel({
    super.key,
    required this.width,
    this.fullScreen = false,
    required this.onClose,
    this.onRunCommand,
    this.controller,
    this.currentCwd,
    this.currentShell,
    this.toolExecutor,
  });

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final ScrollController _scrollController = ScrollController();
  final LayerLink _inputLayerLink = LayerLink();
  TextEditingController? _ownedInputController;
  FocusNode? _ownedInputFocusNode;
  OverlayEntry? _slashOverlay;

  TextEditingController get _inputController =>
      widget.controller ?? _ownedInputController!;
  FocusNode get _inputFocusNode => _ownedInputFocusNode!;

  static const _modeMeta = {
    AiMode.chat: ('Chat', Icons.chat_bubble_outline),
    AiMode.agent: ('Agent', Icons.smart_toy_outlined),
    AiMode.plan: ('Plan', Icons.route_outlined),
  };

  @override
  void initState() {
    super.initState();
    _ownedInputController =
        widget.controller == null ? TextEditingController() : null;
    _ownedInputFocusNode = FocusNode();
    _inputController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dismissSlashOverlay();
    _inputController.removeListener(_onInputChanged);
    _ownedInputController?.dispose();
    _scrollController.dispose();
    _ownedInputFocusNode?.dispose();
    super.dispose();
  }

  // ── Slash command detection ──

  void _onInputChanged() {
    final text = _inputController.text;
    if (text.startsWith('/') && !text.contains('\n')) {
      _showSlashOverlay(text);
    } else {
      _dismissSlashOverlay();
    }
  }

  void _showSlashOverlay(String query) {
    _dismissSlashOverlay();

    final aiProvider = context.read<AiProvider>();
    final matches = _matchSlashCommands(query, aiProvider);
    if (matches.isEmpty) return;

    _slashOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: widget.fullScreen
            ? MediaQuery.sizeOf(ctx).width - 32
            : widget.width - 32,
        child: CompositedTransformFollower(
          link: _inputLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: _SlashCommandPopup(
            items: matches,
            onSelect: _executeSlashItem,
            onDismiss: _dismissSlashOverlay,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_slashOverlay!);
  }

  void _dismissSlashOverlay() {
    _slashOverlay?.remove();
    _slashOverlay = null;
  }

  List<_SlashItem> _matchSlashCommands(String query, AiProvider aiProvider) {
    final q = query.toLowerCase();
    final items = <_SlashItem>[];

    // If user typed just "/" or "/s", show matching top-level commands
    // If user typed "/switch " show configured providers
    // If user typed "/mode " show modes
    // If user typed "/model " show model input hint

    if (q.startsWith('/switch ') || q == '/switch') {
      // Show configured providers as sub-items
      for (final key in aiProvider.configuredProviderKeys) {
        final preset = AiConfig.allPresets[key];
        if (preset == null) continue;
        final model = aiProvider.allProviderConfigs[key]?.model ?? '';
        final isActive = key == aiProvider.activeProviderKey;
        if (q.length > 8) {
          final sub = q.substring(8);
          if (!preset.name.toLowerCase().contains(sub) && !key.contains(sub)) {
            continue;
          }
        }
        items.add(_SlashItem(
          icon: Icons.swap_horiz_rounded,
          label: preset.name,
          subtitle: isActive ? '$model (active)' : model,
          providerKey: key,
          providerColor: preset.color,
          action: () => _doSwitch(key),
        ));
      }
      return items;
    }

    if (q.startsWith('/mode ') || q == '/mode') {
      for (final mode in AiMode.values) {
        final (mLabel, mIcon) = _modeMeta[mode]!;
        if (q.length > 6 && !mLabel.toLowerCase().contains(q.substring(6))) {
          continue;
        }
        items.add(_SlashItem(
          icon: mIcon,
          label: mLabel,
          subtitle: 'Switch to $mLabel mode',
          action: () => _doMode(mode),
        ));
      }
      return items;
    }

    // Top-level command matching
    for (final cmd in SlashCommand.all) {
      if (cmd.command.startsWith(q) || q == '/') {
        items.add(_SlashItem(
          icon: cmd.icon,
          label: cmd.command,
          subtitle: cmd.description,
          action: cmd.hasSubItems
              ? () {
                  if (cmd.command == '/model') {
                    _dismissSlashOverlay();
                    AiQuickActions.showModelPicker(
                      context: context,
                      aiProvider: aiProvider,
                    );
                  } else {
                    _inputController.text = '${cmd.command} ';
                    _inputController.selection = TextSelection.collapsed(
                        offset: _inputController.text.length);
                  }
                }
              : () => _executeTopLevel(cmd.command),
        ));
      }
    }
    return items;
  }

  void _executeSlashItem(_SlashItem item) {
    _dismissSlashOverlay();
    _inputController.clear();
    item.action();
  }

  void _executeTopLevel(String command) {
    _dismissSlashOverlay();
    _inputController.clear();
    final aiProvider = context.read<AiProvider>();

    switch (command) {
      case '/clear':
        aiProvider.clearHistory();
      case '/providers':
        _showProvidersList(aiProvider);
    }
  }

  void _doSwitch(String providerKey) {
    final aiProvider = context.read<AiProvider>();
    aiProvider.switchProvider(providerKey);
    final preset = AiConfig.allPresets[providerKey];
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${preset?.name ?? providerKey}')),
      );
    }
  }

  void _doMode(AiMode mode) {
    context.read<AiProvider>().setMode(mode);
  }

  void _showProvidersList(AiProvider aiProvider) {
    // Add a system message listing providers
    final keys = aiProvider.configuredProviderKeys;
    if (keys.isEmpty) {
      // no-op
      return;
    }
    final lines = keys.map((k) {
      final preset = AiConfig.allPresets[k];
      final model = aiProvider.allProviderConfigs[k]?.model ?? '';
      final active = k == aiProvider.activeProviderKey ? ' (active)' : '';
      return '- **${preset?.name ?? k}**: `$model`$active';
    }).join('\n');

    aiProvider.addCommandResult('/providers', lines);
  }

  // ── Quick provider switcher ──

  void _showQuickSwitcher() {
    final aiProvider = context.read<AiProvider>();
    final keys = aiProvider.configuredProviderKeys;
    if (keys.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Switch Provider',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            ...keys.map((key) {
              final preset = AiConfig.allPresets[key];
              if (preset == null) return const SizedBox.shrink();
              final model = aiProvider.allProviderConfigs[key]?.model ?? '';
              final isActive = key == aiProvider.activeProviderKey;
              return ListTile(
                leading: ProviderIcon(
                    providerKey: key, color: preset.color, size: 28),
                title: Text(preset.name),
                subtitle: Text(model,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: isActive
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _doSwitch(key);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Core messaging ──

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // Handle slash commands that weren't picked from overlay
    if (text.startsWith('/')) {
      _handleSlashText(text);
      return;
    }

    _dismissSlashOverlay();
    final provider = context.read<AiProvider>();
    final executor = widget.toolExecutor ?? defaultToolExecutor;
    provider.sendMessage(
      text,
      cwd: widget.currentCwd,
      shellType: widget.currentShell,
      toolExecutor: executor,
    );
    _inputController.clear();
    _scrollToBottom();
  }

  Future<void> _handleSlashText(String text) async {
    _dismissSlashOverlay();
    final aiProvider = context.read<AiProvider>();

    if (text.startsWith('/switch ')) {
      _inputController.clear();
      final arg = text.substring(8).trim().toLowerCase();
      final key = aiProvider.configuredProviderKeys.firstWhere(
        (k) =>
            k == arg ||
            (AiConfig.allPresets[k]?.name.toLowerCase().contains(arg) ?? false),
        orElse: () => '',
      );
      if (key.isNotEmpty) _doSwitch(key);
    } else if (text.startsWith('/mode ')) {
      _inputController.clear();
      final arg = text.substring(6).trim().toLowerCase();
      for (final mode in AiMode.values) {
        if (mode.name == arg) {
          _doMode(mode);
          break;
        }
      }
    } else if (text.startsWith('/model ')) {
      final model = text.substring(7).trim();
      if (model.isEmpty) {
        _inputController.clear();
        AiQuickActions.showModelPicker(
          context: context,
          aiProvider: aiProvider,
        );
        return;
      }
      _inputController.clear();
      await aiProvider.switchModel(model);
      final preset = AiConfig.allPresets[aiProvider.activeProviderKey];
      aiProvider.addCommandResult(
        '/model $model',
        'Switched ${preset?.name ?? aiProvider.activeProviderKey} model to `$model`',
      );
    } else if (text == '/clear') {
      _inputController.clear();
      aiProvider.clearHistory();
    } else if (text == '/providers') {
      _inputController.clear();
      _showProvidersList(aiProvider);
    }
  }

  void _reuseMessage(String text) {
    _inputController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom() {
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

  // ═══════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════

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
            _buildHeader(theme, aiProvider),
            Expanded(
              child: aiProvider.chatHistory.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildChatList(aiProvider),
            ),
            _buildInputArea(theme, aiProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AiProvider aiProvider) {
    final activePreset = aiProvider.activePreset;
    final activeKey = aiProvider.activeProviderKey;
    final hasMultipleProviders = aiProvider.configuredProviderKeys.length > 1;

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
          // Top row: title + provider chip + actions
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: widget.fullScreen ? 20 : 18,
                  color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'AI',
                style: widget.fullScreen
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              // Provider quick-chip
              if (activePreset != null)
                GestureDetector(
                  onTap: hasMultipleProviders ? _showQuickSwitcher : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activePreset.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProviderIcon(
                            providerKey: activeKey,
                            color: activePreset.color,
                            size: 14),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: widget.fullScreen ? 120 : 80),
                          child: Text(
                            aiProvider.config.model,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: activePreset.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasMultipleProviders)
                          Icon(Icons.expand_more,
                              size: 12, color: activePreset.color),
                      ],
                    ),
                  ),
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
          // Session tabs
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
                        label: Text(session.title,
                            overflow: TextOverflow.ellipsis),
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
          if (!widget.fullScreen) ...[
            _buildModeSelector(theme, aiProvider),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme, AiProvider aiProvider) {
    return SizedBox(
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
          visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
          textStyle: const TextStyle(fontSize: 11),
          padding: EdgeInsets.zero,
        ),
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
          'Ask me anything about shell commands.\nType / for quick commands.',
          ['List all files', 'Show disk usage', '/switch'],
        ),
      AiMode.agent => (
          Icons.smart_toy_outlined,
          'Agent Mode',
          'Tell me a goal and I\'ll execute commands\nstep by step. Type / for commands.',
          ['Set up a git repo', 'Clean up temp files', '/providers'],
        ),
      AiMode.plan => (
          Icons.route_outlined,
          'Plan Mode',
          'Describe what you want to do and I\'ll\ncreate a plan. Type / for commands.',
          ['Deploy this project', 'Migrate database', '/mode chat'],
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
                  Text(title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(desc,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
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
    final isSlash = text.startsWith('/');
    return ActionChip(
      avatar: isSlash
          ? Icon(Icons.terminal, size: 14, color: theme.colorScheme.tertiary)
          : null,
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        if (isSlash) {
          _inputController.text = '$text ';
          _inputController.selection =
              TextSelection.collapsed(offset: _inputController.text.length);
          _inputFocusNode.requestFocus();
        } else {
          _inputController.text = text;
          _sendMessage();
        }
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
        if (message.content.isEmpty &&
            message.role == AiMessageRole.system &&
            message.suggestedCommand == null) {
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
                  Text('Agent running...',
                      style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.tertiary)),
                ],
              ),
            ),
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
                  Text('Plan ready — review and approve',
                      style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.secondary)),
                ],
              ),
            ),
          AiComposerRow(
            controller: _inputController,
            focusNode: _inputFocusNode,
            enabled: !aiProvider.isStreaming,
            hintText: switch (aiProvider.currentMode) {
              AiMode.chat => 'Ask AI... (/ for commands)',
              AiMode.agent => 'Describe a goal... (/ for commands)',
              AiMode.plan => 'What to plan? (/ for commands)',
            },
            minLines: 1,
            maxLines: widget.fullScreen ? 6 : 3,
            layerLink: _inputLayerLink,
            onCommandTap: () => AiQuickActions.showSheet(
              context: context,
              aiProvider: aiProvider,
              controller: _inputController,
            ),
            onSubmit: _sendMessage,
            trailing: IconButton(
              icon: aiProvider.isStreaming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: aiProvider.isStreaming ? null : _sendMessage,
            ),
            accentColor: theme.colorScheme.tertiary,
            iconSize: 16,
            fontSize: 14,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Slash command types & popup
// ═══════════════════════════════════════════════════════════

class _SlashItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String? providerKey;
  final Color? providerColor;
  final VoidCallback action;

  const _SlashItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.providerKey,
    this.providerColor,
    required this.action,
  });
}

class _SlashCommandPopup extends StatelessWidget {
  final List<_SlashItem> items;
  final void Function(_SlashItem) onSelect;
  final VoidCallback onDismiss;

  const _SlashCommandPopup({
    required this.items,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (item.providerKey != null)
                      ProviderIcon(
                        providerKey: item.providerKey!,
                        color: item.providerColor ?? Colors.grey,
                        size: 22,
                      )
                    else
                      Icon(item.icon,
                          size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(item.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
