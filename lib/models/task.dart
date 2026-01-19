import 'package:flutter/material.dart';

/// 任务模型
/// 表示一个可执行的自动化任务（bash脚本）
class Task {
  final String id;
  String name;
  String script;
  String groupId;
  int order;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.name,
    required this.script,
    required this.groupId,
    this.order = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 创建新任务
  static Task create({
    required String name,
    required String script,
    required String groupId,
    int order = 0,
  }) {
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      script: script,
      groupId: groupId,
      order: order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'script': script,
      'groupId': groupId,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      name: json['name'],
      script: json['script'],
      groupId: json['groupId'],
      order: json['order'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Task copyWith({
    String? name,
    String? script,
    String? groupId,
    int? order,
  }) {
    return Task(
      id: id,
      name: name ?? this.name,
      script: script ?? this.script,
      groupId: groupId ?? this.groupId,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}

/// 任务分组模型
class TaskGroup {
  final String id;
  String name;
  int order;
  String? iconName;
  int? colorValue;

  TaskGroup({
    required this.id,
    required this.name,
    this.order = 0,
    this.iconName,
    this.colorValue,
  });

  /// 创建新分组
  static TaskGroup create({
    required String name,
    int order = 0,
    String? iconName,
    int? colorValue,
  }) {
    return TaskGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      order: order,
      iconName: iconName,
      colorValue: colorValue,
    );
  }

  /// 默认分组（未分类）
  static TaskGroup get defaultGroup => TaskGroup(
        id: 'default',
        name: 'Default',
        order: -1,
        iconName: 'folder',
      );

  /// 获取图标
  IconData get icon {
    switch (iconName) {
      case 'folder':
        return Icons.folder;
      case 'code':
        return Icons.code;
      case 'terminal':
        return Icons.terminal;
      case 'cloud':
        return Icons.cloud;
      case 'storage':
        return Icons.storage;
      case 'settings':
        return Icons.settings;
      case 'build':
        return Icons.build;
      case 'bug_report':
        return Icons.bug_report;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'sync':
        return Icons.sync;
      case 'backup':
        return Icons.backup;
      case 'refresh':
        return Icons.refresh;
      default:
        return Icons.folder;
    }
  }

  /// 获取颜色
  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    return Colors.blue;
  }

  /// 可用的图标列表
  static const List<String> availableIcons = [
    'folder',
    'code',
    'terminal',
    'cloud',
    'storage',
    'settings',
    'build',
    'bug_report',
    'rocket_launch',
    'sync',
    'backup',
    'refresh',
  ];

  /// 可用的颜色列表
  static const List<int> availableColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFF44336, // Red
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFE91E63, // Pink
    0xFF607D8B, // Blue Grey
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'iconName': iconName,
      'colorValue': colorValue,
    };
  }

  factory TaskGroup.fromJson(Map<String, dynamic> json) {
    return TaskGroup(
      id: json['id'],
      name: json['name'],
      order: json['order'] ?? 0,
      iconName: json['iconName'],
      colorValue: json['colorValue'],
    );
  }

  TaskGroup copyWith({
    String? name,
    int? order,
    String? iconName,
    int? colorValue,
  }) {
    return TaskGroup(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
