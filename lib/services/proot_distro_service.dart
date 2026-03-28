import 'dart:io';

import '../utils/constants.dart';

class ProotDistroInfo {
  final String alias;
  final String displayName;
  final String rootfsPath;

  const ProotDistroInfo({
    required this.alias,
    required this.displayName,
    required this.rootfsPath,
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
}
