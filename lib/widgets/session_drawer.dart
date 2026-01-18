import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../models/terminal_session.dart';
import '../screens/ssh_manager_screen.dart';

/// 会话列表抽屉
/// 参考 termux-app: TermuxSessionsListViewController.java
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

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sessions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onSettingsTap?.call();
                    },
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),

            // 会话列表
            Expanded(
              child: terminalProvider.sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: terminalProvider.sessions.length,
                      itemBuilder: (context, index) {
                        final session = terminalProvider.sessions[index];
                        return _SessionTile(
                          session: session,
                          isSelected: index == terminalProvider.currentIndex,
                          onTap: () {
                            terminalProvider.switchToSession(index);
                            Navigator.pop(context);
                          },
                          onClose: () {
                            _showCloseConfirmation(
                              context,
                              terminalProvider,
                              index,
                            );
                          },
                          onRename: () {
                            _showRenameDialog(
                              context,
                              terminalProvider,
                              index,
                              session.title,
                            );
                          },
                        );
                      },
                    ),
            ),

            // 底部操作按钮
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SSHManagerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dns),
                      label: const Text('SSH'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        terminalProvider.createSession();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ),
                ],
              ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Session'),
        content: const Text('Are you sure you want to close this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.closeSession(index);
              Navigator.pop(context);
              if (provider.sessions.isEmpty) {
                Navigator.pop(context); // 关闭抽屉
              }
            },
            child: const Text('Close'),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session name',
            border: OutlineInputBorder(),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.renameSession(index, controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

/// 会话列表项
class _SessionTile extends StatelessWidget {
  final TerminalSession session;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onRename;

  const _SessionTile({
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      leading: Icon(
        Icons.terminal,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        session.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatTime(session.createdAt),
        style: theme.textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'close',
            child: Row(
              children: [
                Icon(Icons.close),
                SizedBox(width: 8),
                Text('Close'),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'rename') {
            onRename();
          } else if (value == 'close') {
            onClose();
          }
        },
      ),
      onTap: onTap,
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
