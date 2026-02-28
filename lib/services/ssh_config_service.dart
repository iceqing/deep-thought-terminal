import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/ssh_config_entry.dart';
import '../utils/constants.dart';

/// SSH config 文件解析与序列化服务
class SshConfigService {
  String get sshDir => '${TermuxConstants.homeDir}/.ssh';
  String get configPath => '$sshDir/config';

  /// 加载并解析 ~/.ssh/config
  Future<List<SshConfigEntry>> load() async {
    final file = File(configPath);
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      return parse(content);
    } catch (e) {
      debugPrint('[SshConfigService] Error loading config: $e');
      return [];
    }
  }

  /// 序列化并写回 ~/.ssh/config
  Future<void> save(List<SshConfigEntry> entries) async {
    // 确保 ~/.ssh 目录存在
    final dir = Directory(sshDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 设置目录权限 700
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', sshDir]);
    }

    final content = serialize(entries);
    final file = File(configPath);
    await file.writeAsString(content);

    // 设置文件权限 600
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', configPath]);
    }

    debugPrint('[SshConfigService] Config saved to $configPath');
  }

  /// 解析 SSH config 文本
  List<SshConfigEntry> parse(String content) {
    final entries = <SshConfigEntry>[];
    final lines = content.split('\n');
    final pendingComments = <String>[];
    SshConfigEntry? current;

    for (final line in lines) {
      final trimmed = line.trim();

      // 空行或注释
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        pendingComments.add(line);
        continue;
      }

      // Host 行
      if (trimmed.toLowerCase().startsWith('host ') ||
          trimmed.toLowerCase().startsWith('host=')) {
        // 保存前一个 entry
        if (current != null) {
          entries.add(current);
        }

        final pattern = trimmed.contains('=')
            ? trimmed.substring(trimmed.indexOf('=') + 1).trim()
            : trimmed.substring(5).trim();

        current = SshConfigEntry(
          hostPattern: pattern,
          precedingComments: List.from(pendingComments),
        );
        pendingComments.clear();
        continue;
      }

      // Match 块 - 保留为 raw（不编辑）
      if (trimmed.toLowerCase().startsWith('match ')) {
        if (current != null) {
          entries.add(current);
        }
        current = SshConfigEntry(
          hostPattern: '_match_${trimmed.substring(6).trim()}',
          precedingComments: List.from(pendingComments),
        );
        current.rawDirectives['_raw_match_line'] = trimmed;
        pendingComments.clear();
        continue;
      }

      // 指令行: Key Value 或 Key=Value
      if (current != null) {
        final directive = _parseDirective(trimmed);
        if (directive != null) {
          current.setDirective(directive.key, directive.value);
        }
      } else {
        // Host 块之前的全局指令（无 Host * 头）
        // 创建一个隐式全局块
        current = SshConfigEntry(
          hostPattern: '*',
          precedingComments: List.from(pendingComments),
        );
        pendingComments.clear();
        final directive = _parseDirective(trimmed);
        if (directive != null) {
          current.setDirective(directive.key, directive.value);
        }
      }
    }

    // 添加最后一个 entry
    if (current != null) {
      entries.add(current);
    }

    return entries;
  }

  /// 解析单行指令
  MapEntry<String, String>? _parseDirective(String line) {
    // Key=Value 格式
    if (line.contains('=')) {
      final idx = line.indexOf('=');
      final key = line.substring(0, idx).trim();
      final value = _unquote(line.substring(idx + 1).trim());
      if (key.isNotEmpty) return MapEntry(key, value);
    }

    // Key Value 格式（空格分隔）
    final match = RegExp(r'^(\S+)\s+(.+)$').firstMatch(line);
    if (match != null) {
      final key = match.group(1)!;
      final value = _unquote(match.group(2)!.trim());
      return MapEntry(key, value);
    }

    return null;
  }

  /// 去除引号
  String _unquote(String value) {
    if (value.length >= 2) {
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  /// 序列化为 SSH config 文件格式
  String serialize(List<SshConfigEntry> entries) {
    final buffer = StringBuffer();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      // 输出注释
      for (final comment in entry.precedingComments) {
        buffer.writeln(comment);
      }

      // Match 块原样输出
      if (entry.hostPattern.startsWith('_match_')) {
        final rawLine = entry.rawDirectives.remove('_raw_match_line');
        if (rawLine != null) {
          buffer.writeln(rawLine);
        }
        for (final d in entry.rawDirectives.entries) {
          buffer.writeln('  ${d.key} ${d.value}');
        }
        entry.rawDirectives['_raw_match_line'] = rawLine ?? '';
        if (i < entries.length - 1) buffer.writeln();
        continue;
      }

      // Host 行
      buffer.writeln('Host ${entry.hostPattern}');

      // 输出指令
      for (final d in entry.toDirectives()) {
        // 包含空格的值加引号
        final value = d.value.contains(' ') ? '"${d.value}"' : d.value;
        buffer.writeln('  ${d.key} $value');
      }

      // 块之间空行
      if (i < entries.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
