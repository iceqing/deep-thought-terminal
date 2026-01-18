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

    // 修复脚本中的硬编码路径
    // Termux bootstrap包中的脚本有硬编码的 /data/data/com.termux/ 路径
    await _fixHardcodedPaths();

    // 创建关键二进制文件的包装脚本
    // Termux Android 7+ 的二进制文件有 DT_RUNPATH 指向 /data/data/com.termux/
    // 我们需要用包装脚本强制设置 LD_LIBRARY_PATH 来覆盖它
    await _createBinaryWrappers();

    // 配置APT包管理器
    await _configureApt();
  }

  /// 创建关键二进制文件的包装脚本
  /// DT_RUNPATH 在 ELF 二进制中硬编码了 /data/data/com.termux/ 路径
  /// 我们创建 shell 包装脚本来强制设置正确的 LD_LIBRARY_PATH
  static Future<void> _createBinaryWrappers() async {
    // 首先处理 bash - 它需要特殊的 --norc 参数
    await _createBashWrapper();

    // 需要创建包装脚本的二进制文件列表
    final binariesToWrap = [
      'apt',
      'apt-get',
      'apt-cache',
      'apt-config',
      'apt-key',
      'apt-mark',
      'apt-ftparchive',
      'apt-sortpkgs',
      'dpkg',
      'dpkg-deb',
      'dpkg-query',
      'dpkg-split',
      'dpkg-trigger',
      'gpg',
      'gpgv',
      'curl',
      'wget',
      'ssh',
      'scp',
      'git',
    ];

    for (final binaryName in binariesToWrap) {
      await _createBinaryWrapper(binaryName);
    }

    // 处理 apt methods (http, https, ftp, etc.)
    await _createAptMethodWrappers();
  }

  /// 为 APT methods 创建包装脚本
  /// APT methods 位于 lib/apt/methods/ 目录下
  /// 分两步处理：先处理普通文件，再处理符号链接
  static Future<void> _createAptMethodWrappers() async {
    final methodsDir = Directory('${TermuxConstants.libDir}/apt/methods');

    if (!await methodsDir.exists()) {
      debugPrint('APT methods directory not found');
      return;
    }

    debugPrint('Processing APT methods in ${methodsDir.path}');

    // 第一步：收集所有文件和符号链接
    final regularFiles = <String>[];
    final symlinks = <String>[];

    await for (final entity in methodsDir.list(followLinks: false)) {
      final fileName = path.basename(entity.path);
      // 跳过已处理的 .real 文件
      if (fileName.endsWith('.real')) continue;

      final entityType = await FileSystemEntity.type(entity.path, followLinks: false);
      if (entityType == FileSystemEntityType.link) {
        symlinks.add(fileName);
      } else if (entityType == FileSystemEntityType.file) {
        regularFiles.add(fileName);
      }
    }

    debugPrint('Found ${regularFiles.length} regular files and ${symlinks.length} symlinks');

    // 第二步：先处理普通文件（创建 .real 和包装脚本）
    for (final fileName in regularFiles) {
      debugPrint('Processing apt method (file): $fileName');
      await _createAptMethodWrapper(fileName);
    }

    // 第三步：处理符号链接（此时目标的 .real 应该已存在）
    for (final fileName in symlinks) {
      debugPrint('Processing apt method (symlink): $fileName');
      await _createAptMethodWrapper(fileName);
    }

    // 第四步：确保已知的符号链接方法存在
    // 这些是 SYMLINKS.txt 中定义的方法别名
    // 即使之前的代码删除了它们，我们也要确保创建包装脚本
    await _ensureMethodAlias('https', 'http');
    await _ensureMethodAlias('ssh', 'rsh');

    // 同时处理 lib/apt/solvers 和 lib/apt/planners
    for (final subDir in ['solvers', 'planners']) {
      final dir = Directory('${TermuxConstants.libDir}/apt/$subDir');
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          final fileName = path.basename(entity.path);
          if (fileName.endsWith('.real')) continue;
          await _createAptSubdirWrapper(subDir, fileName);
        }
      }
    }
  }

  /// 确保方法别名存在
  /// 例如: https 应该调用 http.real, ssh 应该调用 rsh.real
  static Future<void> _ensureMethodAlias(String aliasName, String targetName) async {
    final methodsDir = '${TermuxConstants.libDir}/apt/methods';
    final aliasPath = '$methodsDir/$aliasName';
    final targetRealPath = '$methodsDir/$targetName.real';

    try {
      // 检查目标的 .real 文件是否存在
      final targetRealFile = File(targetRealPath);
      if (!await targetRealFile.exists()) {
        debugPrint('Target real file not found for alias $aliasName: $targetRealPath');
        return;
      }

      // 检查别名文件是否已存在且可执行
      final aliasFile = File(aliasPath);
      if (await aliasFile.exists()) {
        // 检查是否是有效的包装脚本
        try {
          final content = await aliasFile.readAsString();
          if (content.contains('#!/system/bin/sh') && content.contains(targetRealPath)) {
            debugPrint('Alias $aliasName already configured correctly');
            return;
          }
        } catch (e) {
          // 可能是二进制文件或无法读取
        }
      }

      // 删除现有文件（可能是损坏的符号链接或旧文件）
      final entityType = await FileSystemEntity.type(aliasPath, followLinks: false);
      if (entityType != FileSystemEntityType.notFound) {
        if (entityType == FileSystemEntityType.link) {
          await Link(aliasPath).delete();
        } else {
          await File(aliasPath).delete();
        }
      }

      // 创建包装脚本
      final libDir = TermuxConstants.libDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$targetRealPath" "\$@"
''';

      await aliasFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', aliasPath]);

      debugPrint('Created/fixed apt method alias: $aliasName -> $targetRealPath');
    } catch (e) {
      debugPrint('Failed to ensure method alias $aliasName: $e');
    }
  }

  /// 为单个 APT method 创建包装脚本
  /// 处理两种情况:
  /// 1. 真正的 ELF 二进制文件 -> 创建 .real 文件和包装脚本
  /// 2. 符号链接到其他方法 (如 https -> http) -> 创建指向同一 .real 的包装脚本
  static Future<void> _createAptMethodWrapper(String methodName) async {
    final methodsDir = '${TermuxConstants.libDir}/apt/methods';
    final methodPath = '$methodsDir/$methodName';
    final realPath = '$methodsDir/$methodName.real';

    try {
      final realFile = File(realPath);

      // 如果 .real 文件已存在，说明已经处理过
      if (await realFile.exists()) {
        debugPrint('APT method $methodName already processed');
        return;
      }

      // 检查文件或符号链接是否存在
      final entityType = await FileSystemEntity.type(methodPath, followLinks: false);
      if (entityType == FileSystemEntityType.notFound) {
        debugPrint('APT method not found: $methodPath');
        return;
      }

      // 如果是符号链接 (如 https -> http, ssh -> rsh)
      if (entityType == FileSystemEntityType.link) {
        final link = Link(methodPath);
        final target = await link.target();
        debugPrint('APT method $methodName is symlink to $target');

        // 删除符号链接
        await link.delete();

        // 找到目标方法的 .real 文件
        // 例如: https -> http, 我们需要找到 http.real
        String targetRealPath;
        if (target.startsWith('/')) {
          targetRealPath = '$target.real';
        } else if (target.contains('/')) {
          targetRealPath = '$methodsDir/$target.real';
        } else {
          // 相对路径，同目录下的方法
          targetRealPath = '$methodsDir/$target.real';
        }

        // 检查目标的 .real 文件是否存在
        final targetRealFile = File(targetRealPath);
        if (await targetRealFile.exists()) {
          // 目标已经被处理过，创建指向同一 .real 的包装脚本
          final libDir = TermuxConstants.libDir;
          final tmpDir = TermuxConstants.tmpDir;

          final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$targetRealPath" "\$@"
''';

          await File(methodPath).writeAsString(wrapperScript);
          await Process.run('chmod', ['755', methodPath]);
          debugPrint('Created apt method wrapper for $methodName -> $targetRealPath');
          return;
        }

        // 目标还没有被处理，找到实际的二进制文件
        String actualBinaryPath;
        if (target.startsWith('/')) {
          actualBinaryPath = target;
        } else if (target.contains('/')) {
          actualBinaryPath = '$methodsDir/$target';
        } else {
          actualBinaryPath = '$methodsDir/$target';
        }

        // 检查目标是否存在
        final actualFile = File(actualBinaryPath);
        if (!await actualFile.exists()) {
          debugPrint('Symlink target not found: $actualBinaryPath');
          return;
        }

        // 检查是否是 ELF 或者是已经创建的包装脚本
        final bytes = await actualFile.openRead(0, 4).first;
        final isElf = bytes.length >= 4 &&
            bytes[0] == 0x7f && bytes[1] == 0x45 &&
            bytes[2] == 0x4c && bytes[3] == 0x46;

        if (isElf) {
          // 目标是 ELF，复制到 .real 并创建包装
          await actualFile.copy(realPath);
          await Process.run('chmod', ['755', realPath]);

          final libDir = TermuxConstants.libDir;
          final tmpDir = TermuxConstants.tmpDir;

          final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$realPath" "\$@"
''';

          await File(methodPath).writeAsString(wrapperScript);
          await Process.run('chmod', ['755', methodPath]);
          debugPrint('Created apt method wrapper for symlink $methodName (copied binary)');
        } else {
          // 目标可能是包装脚本，创建指向目标的包装
          final libDir = TermuxConstants.libDir;
          final tmpDir = TermuxConstants.tmpDir;

          // 尝试找到目标的 .real
          if (await targetRealFile.exists()) {
            final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$targetRealPath" "\$@"
''';
            await File(methodPath).writeAsString(wrapperScript);
          } else {
            // 直接调用目标（它应该是个包装脚本）
            final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$actualBinaryPath" "\$@"
''';
            await File(methodPath).writeAsString(wrapperScript);
          }
          await Process.run('chmod', ['755', methodPath]);
          debugPrint('Created apt method wrapper for symlink $methodName (calling target wrapper)');
        }
        return;
      }

      // 处理普通文件
      final file = File(methodPath);
      if (!await file.exists()) {
        debugPrint('APT method file not found: $methodPath');
        return;
      }

      // 检查是否是 ELF 二进制
      final bytes = await file.openRead(0, 4).first;
      if (bytes.length < 4 ||
          bytes[0] != 0x7f ||
          bytes[1] != 0x45 ||
          bytes[2] != 0x4c ||
          bytes[3] != 0x46) {
        debugPrint('APT method $methodName is not ELF, skipping');
        return;
      }

      // 重命名为 .real
      await file.rename(realPath);
      await Process.run('chmod', ['755', realPath]);

      // 创建包装脚本
      final libDir = TermuxConstants.libDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$realPath" "\$@"
''';

      await File(methodPath).writeAsString(wrapperScript);
      await Process.run('chmod', ['755', methodPath]);

      debugPrint('Created apt method wrapper for $methodName');
    } catch (e) {
      debugPrint('Failed to create apt method wrapper for $methodName: $e');
    }
  }

  /// 为 APT solvers/planners 创建包装脚本
  static Future<void> _createAptSubdirWrapper(String subDir, String fileName) async {
    final filePath = '${TermuxConstants.libDir}/apt/$subDir/$fileName';
    final realPath = '${TermuxConstants.libDir}/apt/$subDir/$fileName.real';

    try {
      final realFile = File(realPath);
      if (await realFile.exists()) {
        return;
      }

      final entityType = await FileSystemEntity.type(filePath, followLinks: false);
      if (entityType == FileSystemEntityType.notFound) {
        return;
      }

      String actualPath = filePath;
      if (entityType == FileSystemEntityType.link) {
        final link = Link(filePath);
        final target = await link.target();
        actualPath = target.startsWith('/') ? target : '${TermuxConstants.libDir}/apt/$subDir/$target';
        await link.delete();
      }

      final actualFile = File(actualPath);
      if (!await actualFile.exists()) {
        return;
      }

      final bytes = await actualFile.openRead(0, 4).first;
      if (bytes.length < 4 || bytes[0] != 0x7f || bytes[1] != 0x45 ||
          bytes[2] != 0x4c || bytes[3] != 0x46) {
        return;
      }

      if (actualPath == filePath) {
        await actualFile.rename(realPath);
      } else {
        await actualFile.copy(realPath);
      }
      await Process.run('chmod', ['755', realPath]);

      final libDir = TermuxConstants.libDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$realPath" "\$@"
''';

      await File(filePath).writeAsString(wrapperScript);
      await Process.run('chmod', ['755', filePath]);

      debugPrint('Created apt $subDir wrapper for $fileName');
    } catch (e) {
      debugPrint('Failed to create apt $subDir wrapper for $fileName: $e');
    }
  }

  /// 创建 bash 包装脚本
  /// bash 二进制有硬编码的配置文件路径指向 /data/data/com.termux/
  /// 需要使用 --norc 参数跳过这些配置文件
  static Future<void> _createBashWrapper() async {
    final bashPath = '${TermuxConstants.binDir}/bash';
    final bashRealPath = '${TermuxConstants.binDir}/bash-real';

    try {
      final bashFile = File(bashPath);
      final bashRealFile = File(bashRealPath);

      // 如果 bash-real 已存在，说明已经处理过
      if (await bashRealFile.exists()) {
        debugPrint('Bash wrapper already configured');
        return;
      }

      // 检查原始 bash 是否存在
      if (!await bashFile.exists()) {
        debugPrint('Original bash not found');
        return;
      }

      // 检查是否是 ELF 文件
      final bytes = await bashFile.openRead(0, 4).first;
      if (bytes.length < 4 || bytes[0] != 0x7f || bytes[1] != 0x45 ||
          bytes[2] != 0x4c || bytes[3] != 0x46) {
        debugPrint('bash is not an ELF file, skipping');
        return;
      }

      // 重命名原始 bash 为 bash-real
      await bashFile.rename(bashRealPath);
      await Process.run('chmod', ['755', bashRealPath]);
      debugPrint('Renamed bash to bash-real');

      // 创建 bash 包装脚本
      final libDir = TermuxConstants.libDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
# Bash wrapper script for Deep Thought terminal
# The original bash has hardcoded paths to /data/data/com.termux/
# This wrapper sets correct library path and uses --norc to skip config files
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
exec "$bashRealPath" --norc "\$@"
''';

      await bashFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', bashPath]);
      debugPrint('Created bash wrapper script');
    } catch (e) {
      debugPrint('Failed to create bash wrapper: $e');
    }
  }

  /// 为指定的二进制文件创建包装脚本
  static Future<void> _createBinaryWrapper(String binaryName) async {
    final binPath = '${TermuxConstants.binDir}/$binaryName';
    final realPath = '${TermuxConstants.binDir}/$binaryName.real';

    try {
      final binFile = File(binPath);
      final realFile = File(realPath);

      // 如果 .real 文件已存在，说明已经处理过
      if (await realFile.exists()) {
        return;
      }

      // 检查原始二进制是否存在
      if (!await binFile.exists()) {
        return;
      }

      // 检查是否是 ELF 二进制文件
      final bytes = await binFile.openRead(0, 4).first;
      if (bytes.length < 4 ||
          bytes[0] != 0x7f ||
          bytes[1] != 0x45 ||  // E
          bytes[2] != 0x4c ||  // L
          bytes[3] != 0x46) {  // F
        // 不是 ELF 文件，可能已经是脚本，跳过
        return;
      }

      // 重命名原始二进制为 .real
      await binFile.rename(realPath);
      await Process.run('chmod', ['755', realPath]);

      // 创建包装脚本
      final libDir = TermuxConstants.libDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      // APT 相关工具需要额外设置 APT_CONFIG 来覆盖硬编码路径
      final isAptTool = binaryName.startsWith('apt') || binaryName.startsWith('dpkg');
      final aptConfigExport = isAptTool
          ? 'export APT_CONFIG="$etcDir/apt/apt.conf"\n'
          : '';

      final wrapperScript = '''#!/system/bin/sh
# Wrapper script to set correct library path
# The original binary has DT_RUNPATH pointing to /data/data/com.termux/
# This wrapper overrides it with the correct path
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
${aptConfigExport}exec "$realPath" "\$@"
''';

      await binFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', binPath]);

      debugPrint('Created wrapper for $binaryName');
    } catch (e) {
      debugPrint('Failed to create wrapper for $binaryName: $e');
    }
  }

  /// 修复脚本中的硬编码Termux路径
  /// Termux bootstrap包中的脚本使用 /data/data/com.termux/ 作为前缀
  /// 我们需要替换为我们应用的路径
  static Future<void> _fixHardcodedPaths() async {
    // 需要替换的路径映射
    final pathReplacements = {
      '/data/data/com.termux/files/usr': TermuxConstants.prefixDir,
      '/data/data/com.termux/files/home': TermuxConstants.homeDir,
      '/data/data/com.termux/files': TermuxConstants.filesDir,
      '@TERMUX_PREFIX@': TermuxConstants.prefixDir,
      '@TERMUX_HOME@': TermuxConstants.homeDir,
    };

    debugPrint('Fixing hardcoded paths in scripts...');

    try {
      // 修复 bin 目录下的所有脚本
      await _fixScriptsInDirectory(TermuxConstants.binDir, pathReplacements);

      // 修复 libexec 目录下的脚本
      final libexecDir = Directory(TermuxConstants.libexecDir);
      if (await libexecDir.exists()) {
        await _fixScriptsInDirectory(TermuxConstants.libexecDir, pathReplacements);
      }

      // 修复 etc 目录下的配置文件
      await _fixScriptsInDirectory(TermuxConstants.etcDir, pathReplacements);

      // 修复 share 目录下的文件
      await _fixScriptsInDirectory(TermuxConstants.shareDir, pathReplacements);

      // 修复 lib 目录下的脚本（如 apt 相关）
      final libAptDir = Directory('${TermuxConstants.libDir}/apt');
      if (await libAptDir.exists()) {
        await _fixScriptsInDirectory(libAptDir.path, pathReplacements);
      }

      debugPrint('Hardcoded paths fixed');
    } catch (e) {
      debugPrint('Failed to fix hardcoded paths: $e');
    }
  }

  /// 修复指定目录下所有脚本的硬编码路径
  static Future<void> _fixScriptsInDirectory(
    String dirPath,
    Map<String, String> replacements,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          await _fixFileIfScript(entity, replacements);
        }
      }
    } catch (e) {
      debugPrint('Error fixing scripts in $dirPath: $e');
    }
  }

  /// 检查文件是否是脚本或文本配置文件，如果是则修复硬编码路径
  static Future<void> _fixFileIfScript(
    File file,
    Map<String, String> replacements,
  ) async {
    try {
      // 读取文件头部
      final bytes = await file.openRead(0, 512).first;
      if (bytes.isEmpty) return;

      // 检查是否是文本文件（脚本以 #! 开头，或者是配置文件）
      final isShebang = bytes.length >= 2 && bytes[0] == 0x23 && bytes[1] == 0x21;
      final fileName = file.path.split('/').last;
      final isConfigFile = fileName.endsWith('.conf') ||
          fileName.endsWith('.cfg') ||
          fileName.endsWith('.sh') ||
          fileName.endsWith('.list') ||
          fileName == 'profile' ||
          fileName == 'bashrc' ||
          fileName == 'environment';

      // 跳过明显的二进制文件（ELF格式）
      if (bytes.length >= 4 &&
          bytes[0] == 0x7f &&
          bytes[1] == 0x45 &&
          bytes[2] == 0x4c &&
          bytes[3] == 0x46) {
        return; // ELF binary
      }

      if (!isShebang && !isConfigFile) return;

      // 读取全部内容
      final content = await file.readAsString();

      // 检查是否包含任何需要替换的路径
      bool needsFix = false;
      for (final oldPath in replacements.keys) {
        if (content.contains(oldPath)) {
          needsFix = true;
          break;
        }
      }

      if (!needsFix) return;

      // 执行所有替换
      var newContent = content;
      for (final entry in replacements.entries) {
        newContent = newContent.replaceAll(entry.key, entry.value);
      }

      // 写回文件
      await file.writeAsString(newContent);

      debugPrint('Fixed: ${file.path}');
    } catch (e) {
      // 可能是二进制文件或无法读取，跳过
    }
  }

  /// 配置APT包管理器
  static Future<void> _configureApt() async {
    try {
      final prefixDir = TermuxConstants.prefixDir;
      final etcDir = TermuxConstants.etcDir;
      final varDir = TermuxConstants.varDir;

      // 创建APT目录结构
      final aptDir = Directory('$etcDir/apt');
      final aptConfDir = Directory('$etcDir/apt/apt.conf.d');
      final aptSourcesDir = Directory('$etcDir/apt/sources.list.d');
      final aptPreferencesDir = Directory('$etcDir/apt/preferences.d');
      final aptTrustedDir = Directory('$etcDir/apt/trusted.gpg.d');
      final varLibApt = Directory('$varDir/lib/apt/lists/partial');
      final varCacheApt = Directory('$varDir/cache/apt/archives/partial');
      final varLogApt = Directory('$varDir/log/apt');

      for (final dir in [aptDir, aptConfDir, aptSourcesDir, aptPreferencesDir,
                         aptTrustedDir, varLibApt, varCacheApt, varLogApt]) {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // 创建 apt.conf 覆盖所有硬编码路径
      final aptConfFile = File('$etcDir/apt/apt.conf');
      final aptConfContent = '''// APT configuration for Deep Thought terminal
// Override hardcoded /data/data/com.termux/ paths

Dir "$prefixDir";
Dir::State "$varDir/lib/apt";
Dir::State::Lists "$varDir/lib/apt/lists";
Dir::State::status "$varDir/lib/dpkg/status";
Dir::Cache "$varDir/cache/apt";
Dir::Cache::archives "$varDir/cache/apt/archives";
Dir::Etc "$etcDir/apt";
Dir::Etc::sourcelist "$etcDir/apt/sources.list";
Dir::Etc::sourceparts "$etcDir/apt/sources.list.d";
Dir::Etc::preferences "$etcDir/apt/preferences";
Dir::Etc::preferencesparts "$etcDir/apt/preferences.d";
Dir::Etc::trusted "$etcDir/apt/trusted.gpg";
Dir::Etc::trustedparts "$etcDir/apt/trusted.gpg.d";
Dir::Bin::methods "${TermuxConstants.libDir}/apt/methods";
Dir::Bin::solvers "${TermuxConstants.libDir}/apt/solvers";
Dir::Bin::planners "${TermuxConstants.libDir}/apt/planners";
Dir::Log "$varDir/log/apt";
Dir::Ignore-Files-Silently "~\$";
''';
      await aptConfFile.writeAsString(aptConfContent);
      debugPrint('APT apt.conf configured');

      // 写入sources.list - 使用Termux官方仓库
      final sourcesListFile = File(TermuxConstants.aptSourcesList);
      const sourcesListContent = '''# Termux main repository
# Primary mirror with CloudFlare CDN
deb https://packages-cf.termux.dev/apt/termux-main stable main
''';
      await sourcesListFile.writeAsString(sourcesListContent);
      debugPrint('APT sources.list configured');

      // 创建dpkg状态目录
      final dpkgDir = Directory('$varDir/lib/dpkg');
      final dpkgInfoDir = Directory('$varDir/lib/dpkg/info');
      final dpkgUpdatesDir = Directory('$varDir/lib/dpkg/updates');

      for (final dir in [dpkgDir, dpkgInfoDir, dpkgUpdatesDir]) {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // 创建dpkg status文件（如果不存在）
      final dpkgStatusFile = File('$varDir/lib/dpkg/status');
      if (!await dpkgStatusFile.exists()) {
        await dpkgStatusFile.writeAsString('');
      }

      // 创建dpkg available文件（如果不存在）
      final dpkgAvailableFile = File('$varDir/lib/dpkg/available');
      if (!await dpkgAvailableFile.exists()) {
        await dpkgAvailableFile.writeAsString('');
      }

      // 创建pkg包装脚本
      await _createPkgScript();

      debugPrint('APT/DPKG configured');
    } catch (e) {
      debugPrint('Failed to configure APT: $e');
    }
  }

  /// 创建pkg包装脚本
  static Future<void> _createPkgScript() async {
    final pkgPath = '${TermuxConstants.binDir}/pkg';

    try {
      final pkgFile = File(pkgPath);

      // 如果已存在且是我们的脚本，跳过
      if (await pkgFile.exists()) {
        final content = await pkgFile.readAsString();
        if (content.contains('Deep Thought')) {
          debugPrint('pkg script already exists');
          return;
        }
      }

      // 创建pkg脚本
      final libDir = TermuxConstants.libDir;
      final prefixDir = TermuxConstants.prefixDir;
      final tmpDir = TermuxConstants.tmpDir;

      final pkgScript = '''#!/system/bin/sh
# pkg - Package manager wrapper for Deep Thought terminal
# Simplified version inspired by Termux

export LD_LIBRARY_PATH="$libDir"
export PREFIX="$prefixDir"
export TMPDIR="$tmpDir"

show_help() {
    echo "Usage: pkg <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  install <pkg>    - Install a package"
    echo "  remove <pkg>     - Remove a package"
    echo "  update           - Update package lists"
    echo "  upgrade          - Upgrade all packages"
    echo "  search <query>   - Search for packages"
    echo "  show <pkg>       - Show package details"
    echo "  list-installed   - List installed packages"
    echo "  list-all         - List all available packages"
    echo "  files <pkg>      - List files in a package"
    echo "  clean            - Clean package cache"
    echo ""
    echo "Examples:"
    echo "  pkg update"
    echo "  pkg install git"
    echo "  pkg search python"
}

case "\$1" in
    install|add|i)
        shift
        apt install -y "\$@"
        ;;
    remove|uninstall|rm)
        shift
        apt remove -y "\$@"
        ;;
    update|upd)
        apt update
        ;;
    upgrade)
        apt upgrade -y
        ;;
    search|se|s)
        shift
        apt search "\$@"
        ;;
    show|info)
        shift
        apt show "\$@"
        ;;
    list-installed|li)
        apt list --installed 2>/dev/null
        ;;
    list-all|la)
        apt list 2>/dev/null
        ;;
    files|f)
        shift
        dpkg -L "\$@"
        ;;
    clean|cl)
        apt clean
        apt autoclean
        ;;
    help|-h|--help|"")
        show_help
        ;;
    *)
        echo "Unknown command: \$1"
        echo "Run 'pkg help' for usage."
        exit 1
        ;;
esac
''';

      await pkgFile.writeAsString(pkgScript);
      await Process.run('chmod', ['755', pkgPath]);
      debugPrint('pkg script created');
    } catch (e) {
      debugPrint('Failed to create pkg script: $e');
    }
  }

  /// 确保关键库文件存在
  /// 如果符号链接不工作，直接复制文件
  static Future<void> _ensureCriticalLibraries() async {
    final libDir = TermuxConstants.libDir;

    // 需要确保存在的库名前缀
    final libPrefixes = [
      'libreadline.so',
      'libhistory.so',
      'libncursesw.so',
      'libncurses.so',
      'libz.so',
      'liblzma.so',
      'libbz2.so',
      'liblz4.so',
      'libzstd.so',
      'libxxhash.so',
      'libgcrypt.so',
      'libgpg-error.so',
      'libiconv.so',
      'libandroid-support.so',
      'libcurl.so',
      'libssl.so',
      'libcrypto.so',
      'libssh2.so',
      'libnghttp2.so',
      'libgnutls.so',
      'libhogweed.so',
      'libnettle.so',
      'libgmp.so',
      'libunistring.so',
      'libidn2.so',
      'libapt-pkg.so',
      'libapt-private.so',
    ];

    debugPrint('Ensuring critical libraries in $libDir');

    final libDirEntity = Directory(libDir);
    if (!await libDirEntity.exists()) {
      debugPrint('Lib directory does not exist');
      return;
    }

    // 获取lib目录中所有实体（包括文件和符号链接）
    final allEntities = <String, FileSystemEntityType>{};
    await for (final entity in libDirEntity.list(followLinks: false)) {
      final name = path.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      allEntities[name] = type;
    }

    debugPrint('Found ${allEntities.length} entities in lib dir');

    // 为每个库前缀确保所有版本链接存在
    for (final prefix in libPrefixes) {
      await _ensureLibraryLinks(libDir, prefix, allEntities);
    }

    debugPrint('Critical libraries check complete');
  }

  /// 为指定的库前缀创建必要的符号链接或复制文件
  /// Android 动态链接器可能不正确处理符号链接，所以我们直接复制文件
  /// 例如: libbz2.so.1.0.8 需要创建:
  ///   - libbz2.so (copy of libbz2.so.1.0.8)
  ///   - libbz2.so.1 (copy of libbz2.so.1.0.8)
  ///   - libbz2.so.1.0 (copy of libbz2.so.1.0.8)
  static Future<void> _ensureLibraryLinks(
    String libDir,
    String prefix,
    Map<String, FileSystemEntityType> allEntities,
  ) async {
    // 找到该库的所有版本
    final matches = allEntities.keys.where((f) => f.startsWith(prefix)).toList();
    if (matches.isEmpty) return;

    // 按版本号排序，找到最完整的版本（通常是最长的文件名）
    matches.sort((a, b) => b.length.compareTo(a.length));
    String fullVersionFile = matches.first;

    // 找到实际的库文件（可能需要解析符号链接）
    String? actualLibPath;
    final fullVersionPath = '$libDir/$fullVersionFile';

    if (allEntities[fullVersionFile] == FileSystemEntityType.link) {
      // 如果是符号链接，尝试解析它
      try {
        final link = Link(fullVersionPath);
        final target = await link.target();
        // 如果是相对路径，转换为绝对路径
        if (!target.startsWith('/')) {
          actualLibPath = '$libDir/$target';
        } else {
          actualLibPath = target;
        }
        // 检查目标文件是否存在
        if (!await File(actualLibPath).exists()) {
          debugPrint('Symlink target not found: $actualLibPath');
          actualLibPath = null;
        }
      } catch (e) {
        debugPrint('Failed to resolve symlink $fullVersionPath: $e');
      }
    } else if (allEntities[fullVersionFile] == FileSystemEntityType.file) {
      actualLibPath = fullVersionPath;
    }

    if (actualLibPath == null) {
      debugPrint('No actual library file found for $prefix');
      return;
    }

    // 确定需要创建的版本
    final versionsToCreate = <String>{};

    // 添加基础版本 (libbz2.so)
    versionsToCreate.add(prefix);

    // 解析版本号并创建所有中间版本
    final versionPart = fullVersionFile.substring(prefix.length);
    if (versionPart.startsWith('.')) {
      final versionNumbers = versionPart.substring(1).split('.');
      String currentVersion = prefix;

      for (int i = 0; i < versionNumbers.length; i++) {
        currentVersion = '$currentVersion.${versionNumbers[i]}';
        versionsToCreate.add(currentVersion);
      }
    }

    // 为每个版本创建文件（复制而非符号链接）
    for (final versionName in versionsToCreate) {
      final versionPath = '$libDir/$versionName';

      // 检查是否已存在且是真实文件
      final exists = await File(versionPath).exists();
      final isLink = await FileSystemEntity.isLink(versionPath);

      if (exists && !isLink) {
        // 已经是真实文件，跳过
        continue;
      }

      try {
        // 删除可能存在的符号链接
        if (isLink) {
          await Link(versionPath).delete();
        }

        // 复制实际库文件
        await File(actualLibPath).copy(versionPath);
        debugPrint('Copied library: $versionName');
      } catch (e) {
        debugPrint('Failed to copy library $versionName: $e');
      }
    }
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
