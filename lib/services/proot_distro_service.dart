import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/constants.dart';

class AvailableDistro {
  final String alias;
  final String displayName;
  final String description;

  const AvailableDistro({
    required this.alias,
    required this.displayName,
    required this.description,
  });
}

class ProotDistroInfo {
  final String alias;
  final String displayName;
  final String rootfsPath;
  final int? sizeBytes; // optional, for display

  const ProotDistroInfo({
    required this.alias,
    required this.displayName,
    required this.rootfsPath,
    this.sizeBytes,
  });
}

class ProotDistroStatus {
  final bool commandAvailable;
  final List<ProotDistroInfo> installedDistros;
  final String? error;

  const ProotDistroStatus({
    required this.commandAvailable,
    required this.installedDistros,
    this.error,
  });

  bool get hasInstalledDistros => installedDistros.isNotEmpty;

  bool get hasUbuntu =>
      installedDistros.any((distro) => distro.alias.toLowerCase() == 'ubuntu');
}

class ProotDistroService {
  ProotDistroService._();

  static final instance = ProotDistroService._();
  static const List<String> _knownAvailableAliases = [
    'ubuntu',
    'debian',
    'archlinux',
    'alpine',
    'fedora',
    'opensuse',
    'rockylinux',
    'almalinux',
    'void',
    'manjaro',
    'artix',
  ];

  static String get _commandPath => '${TermuxConstants.binDir}/proot-distro';
  static String get _pluginsDir => '${TermuxConstants.etcDir}/proot-distro';
  static String get _installedRootfsDir =>
      '${TermuxConstants.varDir}/lib/proot-distro/installed-rootfs';

  Future<ProotDistroStatus> getStatus() async {
    if (!Platform.isAndroid) {
      return const ProotDistroStatus(
        commandAvailable: false,
        installedDistros: [],
      );
    }

    try {
      final commandAvailable = await File(_commandPath).exists();
      final installedDistros = await _listInstalledDistros();

      return ProotDistroStatus(
        commandAvailable: commandAvailable,
        installedDistros: installedDistros,
      );
    } catch (e) {
      return ProotDistroStatus(
        commandAvailable: await File(_commandPath).exists(),
        installedDistros: const [],
        error: e.toString(),
      );
    }
  }

  Future<List<ProotDistroInfo>> _listInstalledDistros() async {
    final rootfsDir = Directory(_installedRootfsDir);
    if (!await rootfsDir.exists()) {
      return const [];
    }

    final distros = <ProotDistroInfo>[];
    await for (final entity in rootfsDir.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final segments = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      final alias = segments.isEmpty ? null : segments.last;
      if (alias == null || alias.startsWith('.')) continue;

      distros.add(
        ProotDistroInfo(
          alias: alias,
          displayName: await _readDisplayName(alias),
          rootfsPath: entity.path,
        ),
      );
    }

    distros.sort((a, b) {
      if (a.alias == 'ubuntu' && b.alias != 'ubuntu') return -1;
      if (a.alias != 'ubuntu' && b.alias == 'ubuntu') return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return distros;
  }

  Future<String> _readDisplayName(String alias) async {
    for (final suffix in ['.sh', '.override.sh']) {
      final file = File('$_pluginsDir/$alias$suffix');
      if (!await file.exists()) continue;

      try {
        final content = await file.readAsString();
        final quotedMatch = RegExp(
          "^DISTRO_NAME=(['\"])(.+?)\\1",
          multiLine: true,
        ).firstMatch(content);
        if (quotedMatch != null) {
          return quotedMatch.group(2)!.trim();
        }

        final rawMatch = RegExp(
          r'^DISTRO_NAME=(.+)$',
          multiLine: true,
        ).firstMatch(content);
        if (rawMatch != null) {
          return rawMatch.group(1)!.trim();
        }
      } catch (_) {}
    }

    return _prettifyAlias(alias);
  }

  String _prettifyAlias(String alias) {
    const knownNames = {
      'ubuntu': 'Ubuntu',
      'debian': 'Debian',
      'archlinux': 'Arch Linux',
      'alpine': 'Alpine Linux',
      'opensuse': 'OpenSUSE',
      'rockylinux': 'Rocky Linux',
      'almalinux': 'AlmaLinux',
      'void': 'Void Linux',
      'fedora': 'Fedora',
      'manjaro': 'Manjaro',
      'artix': 'Artix Linux',
    };

    final knownName = knownNames[alias.toLowerCase()];
    if (knownName != null) {
      return knownName;
    }

    return alias
        .split(RegExp(r'[-_.]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  /// 检查 proot-distro 命令是否可用
  Future<bool> isCommandAvailable() async {
    return File(_commandPath).exists();
  }

  /// 列出所有可安装的发行版（从 proot-distro list 解析）
  Future<List<AvailableDistro>> listAvailableDistros() async {
    final distrosByAlias = <String, AvailableDistro>{};
    try {
      final result = await Process.run(
        _commandPath,
        ['list'],
        environment: _buildEnv(),
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          // 兼容格式:
          // "  * Ubuntu (25.10) < ubuntu >"
          // "    Debian (trixie) < debian >"
          final match = RegExp(
            r'^\s*\*?\s*(.+?)\s*(?:\((.*?)\))?\s*<\s*([^>]+)\s*>\s*$',
          ).firstMatch(line);
          if (match != null) {
            final alias = match.group(3)!.trim();
            final release = match.group(2)?.trim();
            distrosByAlias[alias] = AvailableDistro(
              displayName: match.group(1)!.trim(),
              alias: alias,
              description: release == null || release.isEmpty ? '' : release,
            );
          }
        }
      }
    } catch (_) {}

    final pluginAliases = await _listPluginAliases();
    for (final alias in [
      ...pluginAliases,
      ..._knownAvailableAliases,
    ]) {
      distrosByAlias.putIfAbsent(
        alias,
        () => AvailableDistro(
          alias: alias,
          displayName: _prettifyAlias(alias),
          description: '',
        ),
      );
    }

    final distros = distrosByAlias.values.toList()
      ..sort((a, b) {
        if (a.alias == 'ubuntu' && b.alias != 'ubuntu') return -1;
        if (a.alias != 'ubuntu' && b.alias == 'ubuntu') return 1;
        return a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase());
      });

    return distros;
  }

  /// 安装 proot-distro 本身（通过 pkg install）
  Future<void> installProotDistro({
    void Function(String output)? onOutput,
  }) async {
    final process = await Process.start(
      '${TermuxConstants.binDir}/pkg',
      ['install', '-y', 'proot-distro'],
      environment: _buildEnv(),
    );

    process.stdout.transform(utf8.decoder).listen((data) {
      onOutput?.call(data);
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      onOutput?.call(data);
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        '${TermuxConstants.binDir}/pkg',
        ['install', '-y', 'proot-distro'],
        'pkg install exited with code $exitCode',
        exitCode,
      );
    }
  }

  /// 安装指定发行版
  Future<void> installDistro(
    String alias, {
    void Function(String output)? onOutput,
  }) async {
    if (!await isCommandAvailable()) {
      await installProotDistro(onOutput: onOutput);
    }

    final process = await Process.start(
      _commandPath,
      ['install', alias],
      environment: _buildEnv(),
    );

    process.stdout.transform(utf8.decoder).listen((data) {
      onOutput?.call(data);
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      onOutput?.call(data);
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        _commandPath,
        ['install', alias],
        'proot-distro install exited with code $exitCode',
        exitCode,
      );
    }
  }

  /// 卸载指定发行版
  Future<void> uninstallDistro(String alias) async {
    final result = await Process.run(
      _commandPath,
      ['remove', alias],
      environment: _buildEnv(),
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      final stdout = (result.stdout as String?)?.trim();
      final message = [
        if (stderr != null && stderr.isNotEmpty) stderr,
        if (stdout != null && stdout.isNotEmpty) stdout,
      ].join('\n');

      throw ProcessException(
        _commandPath,
        ['remove', alias],
        message.isEmpty
            ? 'proot-distro remove exited with code ${result.exitCode}'
            : message,
        result.exitCode,
      );
    }
  }

  /// 获取发行版目录大小
  Future<int?> getDistroSize(String rootfsPath) async {
    try {
      final result = await Process.run(
        'du',
        ['-sb', rootfsPath],
        environment: _buildEnv(),
      );
      if (result.exitCode == 0) {
        final parts = (result.stdout as String).trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          return int.tryParse(parts[0]);
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _buildEnv() {
    return {
      'LD_LIBRARY_PATH': TermuxConstants.libDir,
      'HOME': TermuxConstants.homeDir,
      'PREFIX': TermuxConstants.prefixDir,
      'PATH': '${TermuxConstants.binDir}:/system/bin:/system/xbin',
      'TMPDIR': TermuxConstants.tmpDir,
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
    };
  }

  Future<List<String>> _listPluginAliases() async {
    final dir = Directory(_pluginsDir);
    if (!await dir.exists()) {
      return const [];
    }

    final aliases = <String>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;

      final name =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      if (name.startsWith('.')) continue;

      String? alias;
      if (name.endsWith('.override.sh')) {
        alias = name.substring(0, name.length - '.override.sh'.length);
      } else if (name.endsWith('.sh')) {
        alias = name.substring(0, name.length - '.sh'.length);
      }

      if (alias == null || alias.isEmpty) continue;
      aliases.add(alias);
    }

    return aliases.toList()..sort();
  }
}
