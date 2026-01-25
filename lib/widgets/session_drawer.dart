import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_provider.dart';
import '../models/terminal_session.dart';
import '../screens/ssh_manager_screen.dart';
import '../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

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
                    l10n.sessions,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.dns,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SSHManagerScreen(),
                        ),
                      );
                    },
                    tooltip: l10n.manageSSH,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onSettingsTap?.call();
                    },
                    tooltip: l10n.settings,
                  ),
                ],
              ),
            ),

            // 会话列表
            Expanded(
              child: terminalProvider.sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.layers_clear,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noSessions,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
            
            // 底部信息栏 (可选)
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.activeSessionsCount(terminalProvider.sessions.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
    final l10n = AppLocalizations.of(context);
    // 只有一个会话时，或者用户通过滑动删除时，可能不需要确认？
    // 为了防止误触，保留确认是个好习惯，尤其是终端内容可能很重要。
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeSession),
        content: Text('${l10n.close} "${provider.sessions[index].displayName}"?'),
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
                Navigator.pop(context); // Close drawer if empty
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
    
    // 使用 Dismissible 实现滑动删除
    // 注意：Dismissible 需要唯一的 key。session.id 是唯一的。
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        // 复用 onClose 逻辑（这会弹窗）。
        // 如果想让滑动直接删除不确认，可以直接返回 true 并调用逻辑。
        // 为了安全起见，这里触发确认弹窗。
        onClose();
        // 因为 onClose 是 void 且内部弹窗是异步的，这里 Dismissible 需要 Future<bool>
        // 这种写法不太好适配 Dismissible 的 confirmDismiss。
        // 简单起见，我们暂不支持滑动直接触发 Dismissible 的动画删除，
        // 而是滑动后触发 onClose，然后由 Provider 更新列表来重建 UI。
        return false; 
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: Colors.transparent), // 占位保持布局稳定
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onTap,
          onLongPress: onRename, // 长按重命名
          leading: CircleAvatar(
            backgroundColor: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: isSelected 
                ? theme.colorScheme.onPrimary 
                : theme.colorScheme.onSurfaceVariant,
            child: const Icon(Icons.terminal, size: 20),
          ),
          title: Text(
            session.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.onSecondaryContainer : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatTime(session.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected 
                  ? theme.colorScheme.onSecondaryContainer.withOpacity(0.7) 
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
            tooltip: 'Close Session',
            style: IconButton.styleFrom(
              foregroundColor: isSelected 
                  ? theme.colorScheme.onSecondaryContainer 
                  : theme.colorScheme.onSurfaceVariant,
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
