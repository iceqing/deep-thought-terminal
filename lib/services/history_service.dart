import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../models/history_backup.dart';

/// 历史记录条目
class HistoryEntry {
  final int index;
  final String command;
  final DateTime? timestamp;

  HistoryEntry({
    required this.index,
    required this.command,
    this.timestamp,
  });
}

/// 历史记录服务
/// 提供读取、搜索、清除、导出、导入等功能
class HistoryService {
  /// Bash 历史文件路径
  static String get bashHistoryPath => '${TermuxConstants.homeDir}/.bash_history';

  /// Zsh 历史文件路径
  static String get zshHistoryPath => '${TermuxConstants.homeDir}/.zsh_history';

  /// 调试：列出 home 目录下的所有文件
  Future<Map<String, dynamic>> debugInfo() async {
    final info = <String, dynamic>{};

    info['homeDir'] = TermuxConstants.homeDir;
    info['bashHistoryPath'] = bashHistoryPath;
    info['zshHistoryPath'] = zshHistoryPath;

    // 检查 home 目录
    final homeDir = Directory(TermuxConstants.homeDir);
    info['homeDirExists'] = await homeDir.exists();

    // 列出 home 目录下的文件
    if (await homeDir.exists()) {
      try {
        final files = await homeDir.list().map((e) => e.path).toList();
        info['homeFiles'] = files;
      } catch (e) {
        info['homeFilesError'] = e.toString();
      }
    }

    // 检查 bash_history 文件
    final bashFile = File(bashHistoryPath);
    info['bashHistoryExists'] = await bashFile.exists();
    if (await bashFile.exists()) {
      try {
        final stat = await bashFile.stat();
        info['bashHistorySize'] = stat.size;
        info['bashHistoryModified'] = stat.modified.toString();

        // 读取前 500 字节
        final content = await bashFile.readAsString();
        info['bashHistoryContent'] = content.length > 500
            ? '${content.substring(0, 500)}... (truncated)'
            : content;
        info['bashHistoryLines'] = content.split('\n').length;
      } catch (e) {
        info['bashHistoryError'] = e.toString();
      }
    }

    // 检查 zsh_history 文件
    final zshFile = File(zshHistoryPath);
    info['zshHistoryExists'] = await zshFile.exists();
    if (await zshFile.exists()) {
      try {
        final stat = await zshFile.stat();
        info['zshHistorySize'] = stat.size;
        info['zshHistoryModified'] = stat.modified.toString();

        // 读取前 500 字节
        final content = await zshFile.readAsString();
        info['zshHistoryContent'] = content.length > 500
            ? '${content.substring(0, 500)}... (truncated)'
            : content;
        info['zshHistoryLines'] = content.split('\n').length;
      } catch (e) {
        info['zshHistoryError'] = e.toString();
      }
    }

    debugPrint('[HistoryService] Debug info: $info');
    return info;
  }

  /// 读取 Bash 历史记录
  Future<List<HistoryEntry>> readBashHistory() async {
    debugPrint('[HistoryService] Reading bash history from: $bashHistoryPath');

    final file = File(bashHistoryPath);
    final exists = await file.exists();
    debugPrint('[HistoryService] File exists: $exists');

    if (!exists) {
      debugPrint('[HistoryService] Bash history file does not exist');
      return [];
    }

    try {
      final content = await file.readAsString();
      debugPrint('[HistoryService] File content length: ${content.length}');
      debugPrint('[HistoryService] File content preview: ${content.length > 200 ? content.substring(0, 200) : content}');

      final lines = content.split('\n');
      debugPrint('[HistoryService] Total lines: ${lines.length}');

      final entries = <HistoryEntry>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Bash 普通格式：每行一个命令
        // Bash HISTTIMEFORMAT 格式：#timestamp\ncommand
        if (line.startsWith('#')) {
          // 可能是时间戳行，尝试解析
          final timestampStr = line.substring(1);
          final timestamp = int.tryParse(timestampStr);
          if (timestamp != null && i + 1 < lines.length) {
            // 下一行是实际命令
            entries.add(HistoryEntry(
              index: entries.length + 1,
              command: lines[i + 1].trim(),
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
            ));
            i++; // 跳过下一行
            continue;
          }
        }

        entries.add(HistoryEntry(
          index: entries.length + 1,
          command: line,
        ));
      }

      debugPrint('[HistoryService] Parsed ${entries.length} entries');
      return entries;
    } catch (e) {
      debugPrint('[HistoryService] Error reading bash history: $e');
      return [];
    }
  }

  /// 读取 Zsh 历史记录
  /// Zsh 扩展历史格式：: timestamp:0;command
  Future<List<HistoryEntry>> readZshHistory() async {
    debugPrint('[HistoryService] Reading zsh history from: $zshHistoryPath');

    final file = File(zshHistoryPath);
    final exists = await file.exists();
    debugPrint('[HistoryService] Zsh history file exists: $exists');

    if (!exists) {
      debugPrint('[HistoryService] Zsh history file does not exist');
      return [];
    }

    try {
      final content = await file.readAsString();
      debugPrint('[HistoryService] Zsh file content length: ${content.length}');
      debugPrint('[HistoryService] Zsh file content preview: ${content.length > 200 ? content.substring(0, 200) : content}');

      final lines = content.split('\n');
      debugPrint('[HistoryService] Zsh total lines: ${lines.length}');

      final entries = <HistoryEntry>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Zsh 扩展格式：: timestamp:0;command
        if (trimmed.startsWith(': ')) {
          final match = RegExp(r'^: (\d+):\d+;(.+)$').firstMatch(trimmed);
          if (match != null) {
            final timestamp = int.tryParse(match.group(1) ?? '');
            final command = match.group(2) ?? '';
            entries.add(HistoryEntry(
              index: entries.length + 1,
              command: command,
              timestamp: timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
                  : null,
            ));
            continue;
          }
        }

        // 普通格式
        entries.add(HistoryEntry(
          index: entries.length + 1,
          command: trimmed,
        ));
      }

      debugPrint('[HistoryService] Parsed ${entries.length} zsh entries');
      return entries;
    } catch (e) {
      return [];
    }
  }

  /// 获取所有历史记录（合并 Bash 和 Zsh）
  Future<List<HistoryEntry>> getAllHistory() async {
    final bashHistory = await readBashHistory();
    final zshHistory = await readZshHistory();

    // 合并并按时间排序（如果有时间戳）
    final all = [...bashHistory, ...zshHistory];

    // 如果有时间戳，按时间排序；否则保持原顺序
    all.sort((a, b) {
      if (a.timestamp != null && b.timestamp != null) {
        return a.timestamp!.compareTo(b.timestamp!);
      }
      return a.index.compareTo(b.index);
    });

    // 重新编号
    for (int i = 0; i < all.length; i++) {
      all[i] = HistoryEntry(
        index: i + 1,
        command: all[i].command,
        timestamp: all[i].timestamp,
      );
    }

    return all;
  }

  /// 搜索历史记录
  Future<List<HistoryEntry>> searchHistory(String query) async {
    if (query.isEmpty) {
      return getAllHistory();
    }

    final all = await getAllHistory();
    final lowerQuery = query.toLowerCase();

    return all.where((entry) {
      return entry.command.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 清除历史记录
  Future<void> clearHistory({bool bash = true, bool zsh = true}) async {
    if (bash) {
      final bashFile = File(bashHistoryPath);
      if (await bashFile.exists()) {
        await bashFile.writeAsString('');
      }
    }

    if (zsh) {
      final zshFile = File(zshHistoryPath);
      if (await zshFile.exists()) {
        await zshFile.writeAsString('');
      }
    }
  }

  /// 获取历史统计信息
  Future<Map<String, int>> getHistoryStats() async {
    final bashHistory = await readBashHistory();
    final zshHistory = await readZshHistory();

    return {
      'bash': bashHistory.length,
      'zsh': zshHistory.length,
      'total': bashHistory.length + zshHistory.length,
    };
  }

  /// 导出历史记录到 JSON 文件
  Future<File> exportHistory(String destinationPath) async {
    final bashHistory = await readBashHistory();
    final commands = bashHistory.map((e) => e.command).toList();

    final backup = HistoryBackup(
      createdAt: DateTime.now(),
      shellType: 'bash',
      entryCount: commands.length,
      appVersion: AppConstants.version,
      commands: commands,
    );

    final file = File(destinationPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup.toJson()),
    );

    return file;
  }

  /// 从 JSON 文件导入历史记录
  /// [append] 为 true 时追加到现有历史，否则替换
  /// 返回导入的命令数量
  Future<int> importHistory(String sourcePath, {bool append = true}) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('History backup file not found');
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final backup = HistoryBackup.fromJson(json);

    final bashFile = File(bashHistoryPath);

    if (append && await bashFile.exists()) {
      // 追加模式：读取现有历史，添加新命令
      final existingContent = await bashFile.readAsString();
      final newContent = backup.commands.join('\n');
      await bashFile.writeAsString('$existingContent\n$newContent');
    } else {
      // 替换模式：直接写入
      await bashFile.writeAsString(backup.commands.join('\n'));
    }

    return backup.commands.length;
  }
}
