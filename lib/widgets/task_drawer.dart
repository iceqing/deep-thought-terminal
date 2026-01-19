import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

/// 任务抽屉组件
/// 显示任务分组和任务列表，支持执行、编辑、删除任务
class TaskDrawer extends StatefulWidget {
  final Function(Task task)? onTaskExecute;

  const TaskDrawer({
    super.key,
    this.onTaskExecute,
  });

  @override
  State<TaskDrawer> createState() => _TaskDrawerState();
}

class _TaskDrawerState extends State<TaskDrawer> {
  final Set<String> _expandedGroups = {'default'};

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
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
                    Icons.play_circle_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tasks',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () => _showAddOptions(context, taskProvider),
                    tooltip: 'Add',
                  ),
                ],
              ),
            ),

            // 任务列表
            Expanded(
              child: taskProvider.allGroups.isEmpty
                  ? _buildEmptyState(context, taskProvider)
                  : ListView.builder(
                      itemCount: taskProvider.allGroups.length,
                      itemBuilder: (context, index) {
                        final group = taskProvider.allGroups[index];
                        final tasks = taskProvider.getTasksForGroup(group.id);
                        return _GroupSection(
                          group: group,
                          tasks: tasks,
                          isExpanded: _expandedGroups.contains(group.id),
                          onToggle: () {
                            setState(() {
                              if (_expandedGroups.contains(group.id)) {
                                _expandedGroups.remove(group.id);
                              } else {
                                _expandedGroups.add(group.id);
                              }
                            });
                          },
                          onTaskTap: (task) {
                            Navigator.pop(context);
                            widget.onTaskExecute?.call(task);
                          },
                          onTaskEdit: (task) => _showEditTaskDialog(context, taskProvider, task),
                          onTaskDelete: (task) => _showDeleteTaskDialog(context, taskProvider, task),
                          onGroupEdit: group.id != 'default'
                              ? () => _showEditGroupDialog(context, taskProvider, group)
                              : null,
                          onGroupDelete: group.id != 'default'
                              ? () => _showDeleteGroupDialog(context, taskProvider, group)
                              : null,
                          onAddTask: () => _showAddTaskDialog(context, taskProvider, group.id),
                        );
                      },
                    ),
            ),

            // 底部操作
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddGroupDialog(context, taskProvider),
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('New Group'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddTaskDialog(context, taskProvider, 'default'),
                      icon: const Icon(Icons.add),
                      label: const Text('New Task'),
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

  Widget _buildEmptyState(BuildContext context, TaskProvider taskProvider) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a task to automate your workflows',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddTaskDialog(context, taskProvider, 'default'),
            icon: const Icon(Icons.add),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context, TaskProvider taskProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Task'),
              onTap: () {
                Navigator.pop(context);
                _showAddTaskDialog(context, taskProvider, 'default');
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('New Group'),
              onTap: () {
                Navigator.pop(context);
                _showAddGroupDialog(context, taskProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, TaskProvider taskProvider, String groupId) {
    showDialog(
      context: context,
      builder: (context) => _TaskEditDialog(
        groupId: groupId,
        groups: taskProvider.allGroups,
        onSave: (name, script, selectedGroupId) async {
          await taskProvider.createTask(
            name: name,
            script: script,
            groupId: selectedGroupId,
          );
        },
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, TaskProvider taskProvider, Task task) {
    showDialog(
      context: context,
      builder: (context) => _TaskEditDialog(
        task: task,
        groupId: task.groupId,
        groups: taskProvider.allGroups,
        onSave: (name, script, selectedGroupId) async {
          await taskProvider.updateTask(task.copyWith(
            name: name,
            script: script,
            groupId: selectedGroupId,
          ));
        },
      ),
    );
  }

  void _showDeleteTaskDialog(BuildContext context, TaskProvider taskProvider, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              taskProvider.deleteTask(task.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddGroupDialog(BuildContext context, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => _GroupEditDialog(
        onSave: (name, iconName, colorValue) async {
          await taskProvider.createGroup(
            name: name,
            iconName: iconName,
            colorValue: colorValue,
          );
        },
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, TaskProvider taskProvider, TaskGroup group) {
    showDialog(
      context: context,
      builder: (context) => _GroupEditDialog(
        group: group,
        onSave: (name, iconName, colorValue) async {
          await taskProvider.updateGroup(group.copyWith(
            name: name,
            iconName: iconName,
            colorValue: colorValue,
          ));
        },
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, TaskProvider taskProvider, TaskGroup group) {
    final taskCount = taskProvider.getTasksForGroup(group.id).length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${group.name}"?'),
            if (taskCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$taskCount task(s) will be moved to Default group.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              taskProvider.deleteGroup(group.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// 分组区块组件
class _GroupSection extends StatelessWidget {
  final TaskGroup group;
  final List<Task> tasks;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(Task) onTaskTap;
  final Function(Task) onTaskEdit;
  final Function(Task) onTaskDelete;
  final VoidCallback? onGroupEdit;
  final VoidCallback? onGroupDelete;
  final VoidCallback onAddTask;

  const _GroupSection({
    required this.group,
    required this.tasks,
    required this.isExpanded,
    required this.onToggle,
    required this.onTaskTap,
    required this.onTaskEdit,
    required this.onTaskDelete,
    this.onGroupEdit,
    this.onGroupDelete,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 分组头部
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Icon(
                  group.icon,
                  size: 20,
                  color: group.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${tasks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_task',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 20),
                          SizedBox(width: 8),
                          Text('Add Task'),
                        ],
                      ),
                    ),
                    if (onGroupEdit != null)
                      const PopupMenuItem(
                        value: 'edit_group',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Group'),
                          ],
                        ),
                      ),
                    if (onGroupDelete != null)
                      const PopupMenuItem(
                        value: 'delete_group',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Group'),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'add_task':
                        onAddTask();
                        break;
                      case 'edit_group':
                        onGroupEdit?.call();
                        break;
                      case 'delete_group':
                        onGroupDelete?.call();
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        // 任务列表
        if (isExpanded)
          ...tasks.map((task) => _TaskTile(
                task: task,
                onTap: () => onTaskTap(task),
                onEdit: () => onTaskEdit(task),
                onDelete: () => onTaskDelete(task),
              )),
        if (isExpanded && tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No tasks in this group',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// 任务列表项
class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 48, right: 8),
      leading: Icon(
        Icons.play_arrow,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        task.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        task.script.split('\n').first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'run',
            child: Row(
              children: [
                Icon(Icons.play_arrow, size: 20),
                SizedBox(width: 8),
                Text('Run'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          switch (value) {
            case 'run':
              onTap();
              break;
            case 'edit':
              onEdit();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
      ),
      onTap: onTap,
    );
  }
}

/// 任务编辑对话框
class _TaskEditDialog extends StatefulWidget {
  final Task? task;
  final String groupId;
  final List<TaskGroup> groups;
  final Future<void> Function(String name, String script, String groupId) onSave;

  const _TaskEditDialog({
    this.task,
    required this.groupId,
    required this.groups,
    required this.onSave,
  });

  @override
  State<_TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<_TaskEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _scriptController;
  late String _selectedGroupId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _scriptController = TextEditingController(text: widget.task?.script ?? '');
    _selectedGroupId = widget.task?.groupId ?? widget.groupId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Task' : 'New Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                hintText: 'e.g., Git Push',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGroupId,
              decoration: const InputDecoration(
                labelText: 'Group',
                border: OutlineInputBorder(),
              ),
              items: widget.groups.map((group) {
                return DropdownMenuItem(
                  value: group.id,
                  child: Row(
                    children: [
                      Icon(group.icon, size: 20, color: group.color),
                      const SizedBox(width: 8),
                      Text(group.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedGroupId = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scriptController,
              decoration: const InputDecoration(
                labelText: 'Script',
                hintText: 'cd /path && git push',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final script = _scriptController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task name')),
      );
      return;
    }

    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a script')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(name, script, _selectedGroupId);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

/// 分组编辑对话框
class _GroupEditDialog extends StatefulWidget {
  final TaskGroup? group;
  final Future<void> Function(String name, String iconName, int colorValue) onSave;

  const _GroupEditDialog({
    this.group,
    required this.onSave,
  });

  @override
  State<_GroupEditDialog> createState() => _GroupEditDialogState();
}

class _GroupEditDialogState extends State<_GroupEditDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late int _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _selectedIcon = widget.group?.iconName ?? 'folder';
    _selectedColor = widget.group?.colorValue ?? TaskGroup.availableColors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.group != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEditing ? 'Edit Group' : 'New Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Development',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Icon',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskGroup.availableIcons.map((iconName) {
                final tempGroup = TaskGroup(
                  id: '',
                  name: '',
                  iconName: iconName,
                );
                final isSelected = iconName == _selectedIcon;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIcon = iconName;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Icon(
                      tempGroup.icon,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskGroup.availableColors.map((colorValue) {
                final isSelected = colorValue == _selectedColor;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorValue;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(name, _selectedIcon, _selectedColor);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
