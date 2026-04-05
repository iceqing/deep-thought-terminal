import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_config.dart';
import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';
import 'ai_composer_row.dart';
import 'ai_quick_actions.dart';

/// AI 底部快捷输入栏
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
  OverlayEntry? _slashOverlay;
  final LayerLink _layerLink = LayerLink();

  static const _modeHints = {
    AiMode.chat: 'Ask AI...',
    AiMode.agent: 'Describe goal...',
    AiMode.plan: 'What to plan?',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateHasText);
  }

  @override
  void dispose() {
    _dismissSlashOverlay();
    widget.controller.removeListener(_updateHasText);
    super.dispose();
  }

  void _updateHasText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    // Slash command detection
    final text = widget.controller.text;
    if (text.startsWith('/') && !text.contains('\n')) {
      _showSlashOverlay(text);
    } else {
      _dismissSlashOverlay();
    }
  }

  void _showSlashOverlay(String query) {
    _dismissSlashOverlay();
    final aiProvider = context.read<AiProvider>();
    final items = _match(query, aiProvider);
    if (items.isEmpty) return;

    _slashOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.sizeOf(ctx).width - 20,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (ctx, i) => _buildSlashItem(ctx, items[i]),
              ),
            ),
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

  List<_SlashMatch> _match(String query, AiProvider aiProvider) {
    final q = query.toLowerCase();
    final results = <_SlashMatch>[];

    if (q.startsWith('/switch ') || q == '/switch') {
      for (final key in aiProvider.configuredProviderKeys) {
        final preset = AiConfig.allPresets[key];
        if (preset == null) continue;
        final model = aiProvider.allProviderConfigs[key]?.model ?? '';
        if (q.length > 8 &&
            !preset.name.toLowerCase().contains(q.substring(8))) {
          continue;
        }
        results.add(_SlashMatch(
          icon: Icons.swap_horiz_rounded,
          label: preset.name,
          subtitle:
              '${aiProvider.activeProviderKey == key ? "(active) " : ""}$model',
          onTap: () {
            _dismissSlashOverlay();
            aiProvider.switchProvider(key);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to ${preset.name}')),
            );
          },
        ));
      }
      return results;
    }

    if (q.startsWith('/mode ') || q == '/mode') {
      for (final mode in AiMode.values) {
        if (q.length > 6 && !mode.name.toLowerCase().contains(q.substring(6))) {
          continue;
        }
        results.add(_SlashMatch(
          icon: AiQuickActions.modeIcons[mode]!,
          label: '/mode ${mode.name}',
          subtitle: 'Switch to ${mode.name} mode',
          onTap: () {
            _dismissSlashOverlay();
            widget.controller.clear();
            aiProvider.setMode(mode);
          },
        ));
      }
      return results;
    }

    for (final cmd in SlashCommand.all) {
      if (cmd.command.startsWith(q) || q == '/') {
        results.add(_SlashMatch(
          icon: cmd.icon,
          label: cmd.command,
          subtitle: cmd.description,
          onTap: cmd.hasSubItems
              ? () {
                  if (cmd.command == '/model') {
                    _dismissSlashOverlay();
                    AiQuickActions.showModelPicker(
                      context: context,
                      aiProvider: aiProvider,
                    );
                  } else {
                    widget.controller.text = '${cmd.command} ';
                    widget.controller.selection = TextSelection.collapsed(
                        offset: widget.controller.text.length);
                  }
                }
              : () {
                  _dismissSlashOverlay();
                  widget.controller.clear();
                  if (cmd.command == '/clear') {
                    aiProvider.clearHistory();
                  } else if (cmd.command == '/providers') {
                    final keys = aiProvider.configuredProviderKeys;
                    if (keys.isNotEmpty) {
                      final lines = keys.map((k) {
                        final p = AiConfig.allPresets[k];
                        final m = aiProvider.allProviderConfigs[k]?.model ?? '';
                        final act = k == aiProvider.activeProviderKey
                            ? ' (active)'
                            : '';
                        return '- **${p?.name ?? k}**: `$m`$act';
                      }).join('\n');
                      aiProvider.addCommandResult('/providers', lines);
                    }
                  }
                },
        ));
      }
    }
    return results;
  }

  Widget _buildSlashItem(BuildContext ctx, _SlashMatch item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(ctx).colorScheme.onSurface)),
                  Text(item.subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    _dismissSlashOverlay();
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiProvider = context.watch<AiProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final barHeight = isMobile ? 52.0 : 44.0;
    final actionSize = isMobile ? 40.0 : 32.0;
    final activePreset = aiProvider.activePreset;
    final mode = aiProvider.currentMode;

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
      child: AiComposerRow(
        controller: widget.controller,
        enabled: widget.enabled,
        hintText: _modeHints[mode]!,
        minLines: 1,
        maxLines: 1,
        layerLink: _layerLink,
        onCommandTap: () => AiQuickActions.showSheet(
          context: context,
          aiProvider: aiProvider,
          controller: widget.controller,
        ),
        onSubmit: _handleSubmit,
        trailing: AnimatedSwitcher(
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
              onPressed: _hasText ? _handleSubmit : widget.onTapOpenPanel,
              child: Icon(
                _hasText ? Icons.send_rounded : Icons.fullscreen_rounded,
                size: isMobile ? 20 : 18,
              ),
            ),
          ),
        ),
        accentColor: activePreset?.color ?? theme.colorScheme.tertiary,
        iconSize: isMobile ? 17 : 15,
        fontSize: isMobile ? 14 : 13,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 4,
          vertical: isMobile ? 14 : 10,
        ),
      ),
    );
  }
}

class _SlashMatch {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SlashMatch({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}
