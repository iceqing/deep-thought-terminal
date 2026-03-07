import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../models/terminal_session.dart';
import '../screens/ssh_manager_screen.dart';
import '../screens/file_manager_screen.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';

/// 会话列表抽屉 — Modern Mobile Design
class SessionDrawer extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const SessionDrawer({
    super.key,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final terminalProvider = context.watch<TerminalProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sessions = terminalProvider.sessions;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── 顶部：品牌 + 新建按钮 ──
            Padding(
              padding:
                  const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.terminal,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppConstants.appName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 新建会话按钮
                  FilledButton.tonalIcon(
                    onPressed: () {
                      terminalProvider.createSession();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.newSession),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                      textStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),

            // ── 会话计数分隔行 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n.sessions.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sessions.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── 会话列表 ──
            Expanded(
              child: sessions.isEmpty
                  ? _EmptyState(
                      onCreateSession: () {
                        terminalProvider.createSession();
                        Navigator.pop(context);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _SessionCard(
                          session: session,
                          index: index,
                          isSelected: index == terminalProvider.currentIndex,
                          onTap: () {
                            terminalProvider.switchToSession(index);
                            Navigator.pop(context);
                          },
                          onClose: () => _showCloseConfirmation(
                            context,
                            terminalProvider,
                            index,
                          ),
                          onRename: () => _showRenameDialog(
                            context,
                            terminalProvider,
                            index,
                            session.title,
                          ),
                        );
                      },
                    ),
            ),

            // ── 底部工具栏 ──
            Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            _BottomToolbar(
              onFileManager: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FileManagerScreen(),
                  ),
                );
              },
              onSSHManager: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SSHManagerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseConfirmation(
    BuildContext context,
    TerminalProvider provider,
    int index,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeSession),
        content:
            Text('${l10n.close} "${provider.sessions[index].displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              provider.closeSession(index);
              Navigator.pop(context);
              if (provider.sessions.isEmpty) {
                Navigator.pop(context);
              }
            },
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    TerminalProvider provider,
    int index,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameSession),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.sessions,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              provider.renameSession(index, value);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.renameSession(index, controller.text);
              }
              Navigator.pop(context);
            },
            child: Text(l10n.rename),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 空状态
// ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateSession;

  const _EmptyState({required this.onCreateSession});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSessions,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateSession,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.newSession),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 会话卡片
// ─────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final TerminalSession session;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onRename;

  const _SessionCard({
    required this.session,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        onClose();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: isSelected
              ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onRename,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // 左侧强调色条
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),

                // 序号 badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 标题 + 时间
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(session.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                    .withValues(alpha: 0.6)
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 关闭按钮（仅选中项常驻显示，其他项淡化）
                Opacity(
                  opacity: isSelected ? 1.0 : 0.4,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

// ─────────────────────────────────────────────────
// 底部工具栏
// ─────────────────────────────────────────────────

class _BottomToolbar extends StatelessWidget {
  final VoidCallback onFileManager;
  final VoidCallback onSSHManager;

  const _BottomToolbar({
    required this.onFileManager,
    required this.onSSHManager,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarItem(
            icon: Icons.folder_open_rounded,
            label: l10n.fileManager,
            onTap: onFileManager,
          ),
          _ToolbarItem(
            icon: Icons.dns_rounded,
            label: 'SSH',
            onTap: onSSHManager,
          ),
        ],
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
