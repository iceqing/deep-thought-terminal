import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';

/// Bootstrap 安装状态
enum BootstrapStatus {
  notInstalled,
  loading,
  extracting,
  configuring,
  installed,
  error,
}

/// Bootstrap 安装进度回调
typedef BootstrapProgressCallback = void Function(
  BootstrapStatus status,
  double progress,
  String message,
);

/// Termux Bootstrap 管理器
/// 从APK assets加载预置的bootstrap包
class TermuxBootstrap {
  static BootstrapStatus _status = BootstrapStatus.notInstalled;
  static String _errorMessage = '';

  static BootstrapStatus get status => _status;
  static String get errorMessage => _errorMessage;

  /// 检查 Bootstrap 是否已安装
  static Future<bool> isInstalled() async {
    try {
      final bashFile = File(TermuxConstants.bashPath);
      final prefixDir = Directory(TermuxConstants.prefixDir);
      return await bashFile.exists() && await prefixDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// 初始化 Bootstrap 系统
  static Future<bool> initialize({
    BootstrapProgressCallback? onProgress,
  }) async {
    try {
      // 检查是否已安装
      if (await isInstalled()) {
        _status = BootstrapStatus.installed;
        onProgress?.call(_status, 1.0, 'Bootstrap already installed');
        return true;
      }

      // 创建基础目录结构
      _status = BootstrapStatus.configuring;
      onProgress?.call(_status, 0.05, 'Creating directories...');
      await _createDirectories();

      // 从assets加载Bootstrap包
      _status = BootstrapStatus.loading;
      onProgress?.call(_status, 0.1, 'Loading bootstrap from assets...');
      final archiveData = await _loadBootstrapFromAssets();
      if (archiveData == null) {
        throw Exception('Failed to load bootstrap package');
      }

      // 解压
      _status = BootstrapStatus.extracting;
      onProgress?.call(_status, 0.2, 'Extracting bootstrap...');
      await _extractBootstrap(archiveData, onProgress);

      // 配置环境
      _status = BootstrapStatus.configuring;
      onProgress?.call(_status, 0.95, 'Configuring environment...');
      await _configureEnvironment();

      _status = BootstrapStatus.installed;
      onProgress?.call(_status, 1.0, 'Bootstrap installation complete');
      return true;
    } catch (e) {
      _status = BootstrapStatus.error;
      _errorMessage = e.toString();
      onProgress?.call(_status, 0.0, 'Error: $_errorMessage');
      debugPrint('Bootstrap initialization failed: $e');
      return false;
    }
  }

  /// 创建目录结构
  static Future<void> _createDirectories() async {
    final directories = [
      TermuxConstants.filesDir,
      TermuxConstants.prefixDir,
      TermuxConstants.homeDir,
      TermuxConstants.binDir,
      TermuxConstants.libDir,
      TermuxConstants.etcDir,
      TermuxConstants.shareDir,
      TermuxConstants.tmpDir,
      TermuxConstants.varDir,
      TermuxConstants.termuxConfigDir,
      TermuxConstants.configDir,
    ];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  /// 从assets加载Bootstrap包
  static Future<List<int>?> _loadBootstrapFromAssets() async {
    try {
      final arch = await _getCpuArch();
      String assetPath;

      if (arch == 'x86_64') {
        assetPath = 'assets/bootstrap-x86_64.zip';
      } else {
        // 默认使用aarch64 (ARM64)
        assetPath = 'assets/bootstrap-aarch64.zip';
      }

      debugPrint('Loading bootstrap from: $assetPath (arch: $arch)');

      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to load bootstrap from assets: $e');
      return null;
    }
  }

  /// 获取 CPU 架构
  static Future<String> _getCpuArch() async {
    try {
      // 在Android上检测架构
      final result = await Process.run('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      debugPrint('Detected CPU architecture: $arch');
      return arch;
    } catch (e) {
      return 'aarch64'; // 默认 ARM64
    }
  }

  /// 解压 Bootstrap 包
  static Future<void> _extractBootstrap(
    List<int> archiveData,
    BootstrapProgressCallback? onProgress,
  ) async {
    try {
      final archive = ZipDecoder().decodeBytes(archiveData);
      final totalFiles = archive.files.length;
      var extractedFiles = 0;
      final symlinks = <String, String>{};
      final executableFiles = <String>[];

      for (final file in archive.files) {
        final filename = file.name;

        // 处理SYMLINKS.txt
        if (filename == 'SYMLINKS.txt') {
          final content = String.fromCharCodes(file.content as List<int>);
          _parseSymlinks(content, symlinks);
          continue;
        }

        // 计算目标路径
        final targetPath = path.join(TermuxConstants.prefixDir, filename);

        if (file.isFile) {
          final outFile = File(targetPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);

          // 记录需要设置可执行权限的文件
          if (_shouldBeExecutable(filename)) {
            executableFiles.add(targetPath);
          }
        } else {
          await Directory(targetPath).create(recursive: true);
        }

        extractedFiles++;
        if (extractedFiles % 100 == 0) {
          final progress = 0.2 + (extractedFiles / totalFiles) * 0.7;
          onProgress?.call(
            BootstrapStatus.extracting,
            progress,
            'Extracting: $extractedFiles/$totalFiles',
          );
        }
      }

      // 批量设置可执行权限
      onProgress?.call(
        BootstrapStatus.configuring,
        0.9,
        'Setting permissions for ${executableFiles.length} files...',
      );

      await _setExecutablePermissions(executableFiles);

      // 创建符号链接
      await _createSymlinks(symlinks);
    } catch (e) {
      debugPrint('Extraction failed: $e');
      rethrow;
    }
  }

  /// 批量设置可执行权限
  static Future<void> _setExecutablePermissions(List<String> files) async {
    for (final filePath in files) {
      try {
        // 使用chmod设置rwx权限 (0700 = owner can read, write, execute)
        final result = await Process.run('chmod', ['700', filePath]);
        if (result.exitCode != 0) {
          debugPrint('chmod failed for $filePath: ${result.stderr}');
        }
      } catch (e) {
        debugPrint('Failed to set permission for $filePath: $e');
      }
    }

    // 验证关键文件的权限
    final bashPath = TermuxConstants.bashPath;
    try {
      final stat = await Process.run('ls', ['-la', bashPath]);
      debugPrint('Bash permissions: ${stat.stdout}');
    } catch (e) {
      debugPrint('Could not verify bash permissions: $e');
    }
  }

  /// 解析SYMLINKS.txt
  /// 格式: target←link_path
  /// 例如: libreadline.so.8.3←./lib/libreadline.so.8
  /// 表示创建符号链接 ./lib/libreadline.so.8 -> libreadline.so.8.3
  static void _parseSymlinks(String content, Map<String, String> symlinks) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('←');
      if (parts.length == 2) {
        final target = parts[0].trim();    // 符号链接指向的目标
        final linkPath = parts[1].trim();  // 符号链接的路径
        symlinks[linkPath] = target;
      }
    }
  }

  /// 判断文件是否应该有执行权限
  static bool _shouldBeExecutable(String filename) {
    return filename.startsWith('bin/') ||
           filename.startsWith('libexec/') ||
           filename.startsWith('lib/apt/');
  }

  /// 创建符号链接
  static Future<void> _createSymlinks(Map<String, String> symlinks) async {
    int created = 0;
    int failed = 0;

    for (final entry in symlinks.entries) {
      // entry.key = 符号链接路径 (如 ./lib/libreadline.so.8)
      // entry.value = 目标 (如 libreadline.so.8.3)
      String linkPathRaw = entry.key;
      final target = entry.value;

      // 移除开头的 "./"
      if (linkPathRaw.startsWith('./')) {
        linkPathRaw = linkPathRaw.substring(2);
      }

      final linkPath = path.join(TermuxConstants.prefixDir, linkPathRaw);

      try {
        final link = Link(linkPath);
        final parentDir = Directory(path.dirname(linkPath));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        if (await link.exists()) {
          await link.delete();
        }
        // 创建相对符号链接
        await link.create(target);
        created++;

        // 调试: 验证关键库链接
        if (linkPathRaw.contains('libreadline')) {
          debugPrint('Created readline symlink: $linkPath -> $target');
          // 验证链接是否有效
          final exists = await link.exists();
          final resolvedTarget = await link.target();
          debugPrint('Symlink exists: $exists, resolves to: $resolvedTarget');
        }
      } catch (e) {
        debugPrint('Failed to create symlink: $linkPath -> $target: $e');
        failed++;
      }
    }

    debugPrint('Symlinks created: $created, failed: $failed');

    // 验证lib目录内容
    try {
      final libDir = Directory(TermuxConstants.libDir);
      if (await libDir.exists()) {
        final result = await Process.run('ls', ['-la', '${TermuxConstants.libDir}/libreadline*']);
        debugPrint('Readline libs: ${result.stdout}');
      }
    } catch (e) {
      debugPrint('Could not list lib dir: $e');
    }
  }

  /// 配置环境
  static Future<void> _configureEnvironment() async {
    // 创建环境变量文件
    await TermuxEnvironment.writeEnvironmentFile();

    // 设置tmp目录权限
    try {
      await Process.run('chmod', ['1777', TermuxConstants.tmpDir]);
    } catch (e) {
      debugPrint('Failed to set tmp permissions: $e');
    }

    // 确保关键库文件有正确的链接
    // Android的动态链接器可能不支持某些类型的符号链接
    await _ensureCriticalLibraries();
  }

  /// 确保关键库文件存在
  /// 如果符号链接不工作，直接复制文件
  static Future<void> _ensureCriticalLibraries() async {
    final libDir = TermuxConstants.libDir;

    // 关键库映射: 链接名 -> 实际文件名
    final criticalLibs = {
      'libreadline.so.8': 'libreadline.so.8.3',
      'libreadline.so': 'libreadline.so.8.3',
      'libhistory.so.8': 'libhistory.so.8.3',
      'libhistory.so': 'libhistory.so.8.3',
      'libncursesw.so.6': 'libncursesw.so.6.5',
      'libncursesw.so': 'libncursesw.so.6.5',
      'libiconv.so': 'libiconv.so',
      'libandroid-support.so': 'libandroid-support.so',
    };

    for (final entry in criticalLibs.entries) {
      final linkPath = '$libDir/${entry.key}';
      final targetPath = '$libDir/${entry.value}';

      try {
        final linkFile = File(linkPath);
        final targetFile = File(targetPath);

        // 检查目标文件是否存在
        if (!await targetFile.exists()) {
          debugPrint('Target library not found: $targetPath');
          continue;
        }

        // 检查链接是否有效
        if (await linkFile.exists()) {
          debugPrint('Library link OK: $linkPath');
          continue;
        }

        // 链接无效，尝试重新创建
        debugPrint('Library link invalid, recreating: $linkPath -> ${entry.value}');

        // 删除可能存在的损坏链接
        try {
          final link = Link(linkPath);
          if (await link.exists()) {
            await link.delete();
          }
        } catch (e) {
          // 忽略
        }

        // 如果是同一个文件，跳过
        if (entry.key == entry.value) {
          continue;
        }

        // 尝试创建符号链接
        try {
          await Link(linkPath).create(entry.value);
          debugPrint('Created symlink: $linkPath -> ${entry.value}');
        } catch (e) {
          // 符号链接失败，复制文件作为备份方案
          debugPrint('Symlink failed, copying file: $e');
          await targetFile.copy(linkPath);
          debugPrint('Copied library: $targetPath -> $linkPath');
        }
      } catch (e) {
        debugPrint('Error ensuring library $linkPath: $e');
      }
    }

    // 最终验证
    final readlineLib = File('$libDir/libreadline.so.8');
    debugPrint('Final check - libreadline.so.8 exists: ${await readlineLib.exists()}');
  }

  /// 获取 Shell 路径
  static Future<String> getShellPath() async {
    final bashFile = File(TermuxConstants.bashPath);
    if (await bashFile.exists()) {
      return TermuxConstants.bashPath;
    }
    return TermuxConstants.fallbackShell;
  }
}

/// Termux 环境变量管理
class TermuxEnvironment {
  /// 生成环境变量
  static Map<String, String> generateEnvironment() {
    return {
      'HOME': TermuxConstants.homeDir,
      'PREFIX': TermuxConstants.prefixDir,
      'PATH': '${TermuxConstants.binDir}:/system/bin:/system/xbin',
      'TMPDIR': TermuxConstants.tmpDir,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      'LANG': 'en_US.UTF-8',
      'SHELL': TermuxConstants.bashPath,
      // LD_LIBRARY_PATH for dynamically linked binaries
      'LD_LIBRARY_PATH': TermuxConstants.libDir,
      // LD_PRELOAD to help with library loading
      'ANDROID_ROOT': '/system',
      'ANDROID_DATA': '/data',
    };
  }

  /// 写入环境变量文件
  static Future<void> writeEnvironmentFile() async {
    try {
      final envDir = Directory(TermuxConstants.termuxConfigDir);
      if (!await envDir.exists()) {
        await envDir.create(recursive: true);
      }

      final env = generateEnvironment();
      final lines = env.entries.map((e) => 'export ${e.key}="${e.value}"').toList();

      final envFile = File(TermuxConstants.envFile);
      await envFile.writeAsString(lines.join('\n'));
    } catch (e) {
      debugPrint('Failed to write environment file: $e');
    }
  }

  /// 获取完整环境变量
  static Map<String, String> getFullEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(generateEnvironment());
    return env;
  }
}
