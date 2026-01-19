import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

/// 任务管理状态提供者
/// 管理自动化任务的CRUD操作和持久化
class TaskProvider extends ChangeNotifier {
  static const String _tasksKey = 'tasks';
  static const String _groupsKey = 'task_groups';

  late SharedPreferences _prefs;
  bool _initialized = false;

  List<Task> _tasks = [];
  List<TaskGroup> _groups = [];

  // Getters
  bool get initialized => _initialized;
  List<Task> get tasks => List.unmodifiable(_tasks);
  List<TaskGroup> get groups => List.unmodifiable(_groups);

  /// 获取所有分组（包含默认分组）
  List<TaskGroup> get allGroups {
    final defaultGroup = TaskGroup.defaultGroup;
    final sortedGroups = [..._groups]..sort((a, b) => a.order.compareTo(b.order));
    return [defaultGroup, ...sortedGroups];
  }

  /// 获取指定分组的任务
  List<Task> getTasksForGroup(String groupId) {
    return _tasks
        .where((t) => t.groupId == groupId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadData();
    _initialized = true;
    notifyListeners();
  }

  /// 从 SharedPreferences 加载数据
  void _loadData() {
    // 加载任务
    final tasksJson = _prefs.getString(_tasksKey);
    if (tasksJson != null) {
      try {
        final List<dynamic> tasksList = json.decode(tasksJson);
        _tasks = tasksList.map((j) => Task.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Failed to load tasks: $e');
        _tasks = [];
      }
    }

    // 加载分组
    final groupsJson = _prefs.getString(_groupsKey);
    if (groupsJson != null) {
      try {
        final List<dynamic> groupsList = json.decode(groupsJson);
        _groups = groupsList.map((j) => TaskGroup.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Failed to load task groups: $e');
        _groups = [];
      }
    }
  }

  /// 保存任务到 SharedPreferences
  Future<void> _saveTasks() async {
    final tasksJson = json.encode(_tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(_tasksKey, tasksJson);
  }

  /// 保存分组到 SharedPreferences
  Future<void> _saveGroups() async {
    final groupsJson = json.encode(_groups.map((g) => g.toJson()).toList());
    await _prefs.setString(_groupsKey, groupsJson);
  }

  // ==================== 任务操作 ====================

  /// 添加任务
  Future<void> addTask(Task task) async {
    _tasks.add(task);
    await _saveTasks();
    notifyListeners();
  }

  /// 创建并添加任务
  Future<Task> createTask({
    required String name,
    required String script,
    String? groupId,
  }) async {
    final task = Task.create(
      name: name,
      script: script,
      groupId: groupId ?? 'default',
      order: getTasksForGroup(groupId ?? 'default').length,
    );
    await addTask(task);
    return task;
  }

  /// 更新任务
  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      await _saveTasks();
      notifyListeners();
    }
  }

  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveTasks();
    notifyListeners();
  }

  /// 移动任务到其他分组
  Future<void> moveTaskToGroup(String taskId, String newGroupId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].groupId = newGroupId;
      _tasks[index].order = getTasksForGroup(newGroupId).length;
      await _saveTasks();
      notifyListeners();
    }
  }

  /// 重新排序任务
  Future<void> reorderTasks(String groupId, int oldIndex, int newIndex) async {
    final groupTasks = getTasksForGroup(groupId);
    if (oldIndex < 0 || oldIndex >= groupTasks.length) return;
    if (newIndex < 0 || newIndex > groupTasks.length) return;

    if (newIndex > oldIndex) newIndex--;
    final task = groupTasks.removeAt(oldIndex);
    groupTasks.insert(newIndex, task);

    // 更新顺序
    for (int i = 0; i < groupTasks.length; i++) {
      final idx = _tasks.indexWhere((t) => t.id == groupTasks[i].id);
      if (idx != -1) {
        _tasks[idx].order = i;
      }
    }

    await _saveTasks();
    notifyListeners();
  }

  // ==================== 分组操作 ====================

  /// 添加分组
  Future<void> addGroup(TaskGroup group) async {
    _groups.add(group);
    await _saveGroups();
    notifyListeners();
  }

  /// 创建并添加分组
  Future<TaskGroup> createGroup({
    required String name,
    String? iconName,
    int? colorValue,
  }) async {
    final group = TaskGroup.create(
      name: name,
      order: _groups.length,
      iconName: iconName ?? 'folder',
      colorValue: colorValue ?? TaskGroup.availableColors[0],
    );
    await addGroup(group);
    return group;
  }

  /// 更新分组
  Future<void> updateGroup(TaskGroup group) async {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
      await _saveGroups();
      notifyListeners();
    }
  }

  /// 删除分组（分组内的任务移动到默认分组）
  Future<void> deleteGroup(String groupId) async {
    if (groupId == 'default') return; // 不能删除默认分组

    // 将该分组的任务移动到默认分组
    for (final task in _tasks) {
      if (task.groupId == groupId) {
        task.groupId = 'default';
      }
    }

    _groups.removeWhere((g) => g.id == groupId);
    await _saveTasks();
    await _saveGroups();
    notifyListeners();
  }

  /// 重新排序分组
  Future<void> reorderGroups(int oldIndex, int newIndex) async {
    // 注意：这里的 index 是不包含默认分组的
    if (oldIndex < 0 || oldIndex >= _groups.length) return;
    if (newIndex < 0 || newIndex > _groups.length) return;

    if (newIndex > oldIndex) newIndex--;
    final group = _groups.removeAt(oldIndex);
    _groups.insert(newIndex, group);

    // 更新顺序
    for (int i = 0; i < _groups.length; i++) {
      _groups[i].order = i;
    }

    await _saveGroups();
    notifyListeners();
  }

  /// 获取分组信息
  TaskGroup? getGroup(String groupId) {
    if (groupId == 'default') return TaskGroup.defaultGroup;
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  /// 获取任务
  Task? getTask(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }
}
