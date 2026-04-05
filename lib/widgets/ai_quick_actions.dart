import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../models/ai_chat_message.dart';
import '../providers/ai_provider.dart';

class AiQuickActions {
  static const modeIcons = {
    AiMode.chat: Icons.chat_bubble_outline,
    AiMode.agent: Icons.smart_toy_outlined,
    AiMode.plan: Icons.route_outlined,
  };

  static const modeLabels = {
    AiMode.chat: 'Chat',
    AiMode.agent: 'Agent',
    AiMode.plan: 'Plan',
  };

  static Future<void> showSheet({
    required BuildContext context,
    required AiProvider aiProvider,
    required TextEditingController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.58,
            minChildSize: 0.35,
            maxChildSize: 0.82,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mode',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      ...AiMode.values.map((mode) {
                        final selected = mode == aiProvider.currentMode;
                        return ListTile(
                          leading: Icon(modeIcons[mode], size: 20),
                          title: Text(modeLabels[mode]!),
                          trailing: selected
                              ? Icon(Icons.check,
                                  size: 18, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            aiProvider.setMode(mode);
                          },
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Commands',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      ...SlashCommand.all
                          .where((cmd) => cmd.command != '/mode')
                          .map(
                            (cmd) => ListTile(
                              leading: Icon(cmd.icon, size: 20),
                              title: Text(cmd.command),
                              subtitle: Text(cmd.description),
                              trailing: cmd.hasSubItems
                                  ? const Icon(Icons.chevron_right, size: 18)
                                  : null,
                              onTap: () async {
                                final nav = Navigator.of(ctx);
                                Navigator.pop(ctx);
                                if (cmd.command == '/model') {
                                  await showModelPicker(
                                    context: nav.context,
                                    aiProvider: aiProvider,
                                  );
                                } else {
                                  await handleCommand(
                                    command: cmd.command,
                                    aiProvider: aiProvider,
                                    controller: controller,
                                  );
                                }
                              },
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> handleCommand({
    required String command,
    required AiProvider aiProvider,
    required TextEditingController controller,
  }) async {
    switch (command) {
      case '/clear':
        aiProvider.clearHistory();
        return;
      case '/providers':
        final keys = aiProvider.configuredProviderKeys;
        if (keys.isNotEmpty) {
          final lines = keys.map((k) {
            final preset = AiConfig.allPresets[k];
            final model = aiProvider.allProviderConfigs[k]?.model ?? '';
            final active = k == aiProvider.activeProviderKey ? ' (active)' : '';
            return '- **${preset?.name ?? k}**: `$model`$active';
          }).join('\n');
          aiProvider.addCommandResult('/providers', lines);
        }
        return;
      default:
        controller
          ..text = '$command '
          ..selection = TextSelection.collapsed(offset: command.length + 1);
    }
  }

  /// 显示模型选择器（类似 Claude Code 风格）
  static Future<void> showModelPicker({
    required BuildContext context,
    required AiProvider aiProvider,
  }) async {
    final activeKey = aiProvider.activeProviderKey;
    final preset = AiConfig.allPresets[activeKey];
    final suggestions = preset?.commonModels ?? [];
    final currentModel = aiProvider.config.model;

    await showModalBottomSheet(
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
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Select Model',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (preset != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: preset.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: preset.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No models available for this provider'),
              )
            else
              ...suggestions.map((model) {
                final isActive = model == currentModel;
                return ListTile(
                  leading: Icon(
                    Icons.model_training,
                    size: 20,
                    color: isActive
                        ? Theme.of(ctx).colorScheme.primary
                        : Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    model,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Theme.of(ctx).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isActive
                      ? Icon(Icons.check,
                          size: 20, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await aiProvider.switchModel(model);
                    aiProvider.addCommandResult(
                      '/model $model',
                      'Switched ${preset?.name ?? activeKey} model to `$model`',
                    );
                  },
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
