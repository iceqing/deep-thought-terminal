import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
        _status = BootstrapStatus.configuring;
        onProgress?.call(_status, 0.9, 'Updating configuration...');

        // 即使已安装，也要更新配置（修复路径、证书等）
        await _configureEnvironment();

        _status = BootstrapStatus.installed;
        onProgress?.call(_status, 1.0, 'Bootstrap ready');
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

    // 补丁二进制文件中的硬编码路径
    // Termux 二进制文件中硬编码了 /data/data/com.termux/ 路径
    // 我们的包名 com.dpterm 与 com.termux 长度相同，可以直接替换
    await _patchBinaryPaths();

    // 补丁 dpkg info 文件中的硬编码路径
    // dpkg 的 .list 文件记录了包文件路径，需要修正
    await _patchDpkgInfoFiles();

    // 修复脚本中的硬编码路径
    // Termux bootstrap包中的脚本有硬编码的 /data/data/com.termux/ 路径
    await _fixHardcodedPaths();

    // 创建关键二进制文件的包装脚本
    // Termux Android 7+ 的二进制文件有 DT_RUNPATH 指向 /data/data/com.termux/
    // 我们需要用包装脚本强制设置 LD_LIBRARY_PATH 来覆盖它
    await _createBinaryWrappers();

    // 修复脚本的 shebang - 必须在 _createBinaryWrappers 之后运行
    // 因为 bash 现在是包装脚本，需要将 shebang 改为使用 bash-real
    await _fixScriptShebangs();

    // 配置APT包管理器
    await _configureApt();

    // 创建工具脚本
    await createSetupStorageScript();

    // 创建 chsh 替代脚本（不依赖 termux-am 广播）
    await _createChshScript();

    // 创建 termux-reload-settings 替代脚本
    await _createTermuxReloadSettingsScript();

    // 创建 bashrc 配置文件
    await _createBashrc();

    // 创建 zshrc 配置文件
    await _createZshrc();
  }

  /// 创建 bashrc 配置文件
  static Future<void> _createBashrc() async {
    final bashrcPath = '${TermuxConstants.homeDir}/.bashrc';
    final bashrcFile = File(bashrcPath);

    // 如果已存在则不覆盖用户配置
    if (await bashrcFile.exists()) {
      return;
    }

    final bashrcContent = '''
# ~/.bashrc - Deep Thought Terminal Configuration

# 提示符设置 - 绿色路径
PS1='\\[\\e[0;32m\\]\\w\\[\\e[0m\\] \\\$ '

# 启用颜色支持
export CLICOLOR=1
export CLICOLOR_FORCE=1

# LS_COLORS 配置
# di=目录 ln=链接 so=socket pi=管道 ex=可执行 bd=块设备 cd=字符设备
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34:*.tar=1;31:*.gz=1;31:*.zip=1;31:*.7z=1;31:*.rar=1;31:*.jpg=1;35:*.jpeg=1;35:*.png=1;35:*.gif=1;35:*.bmp=1;35:*.mp3=1;36:*.mp4=1;36:*.mkv=1;36:*.avi=1;36:*.pdf=1;33:*.doc=1;33:*.txt=0;37'

# 常用命令别名 - 启用颜色
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'

# 便捷别名
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias q='exit'

# 历史记录配置
export HISTFILE="\$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:ignorespace:erasedups

# 追加历史而不是覆盖（需要在交互式 bash 中执行）
shopt -s histappend 2>/dev/null

# 每条命令后保存历史（防止异常退出丢失历史）
PROMPT_COMMAND="history -a; \$PROMPT_COMMAND"

# 让 less 支持颜色
export LESS='-R'
export LESS_TERMCAP_mb=\$'\\e[1;31m'
export LESS_TERMCAP_md=\$'\\e[1;36m'
export LESS_TERMCAP_me=\$'\\e[0m'
export LESS_TERMCAP_so=\$'\\e[1;44;33m'
export LESS_TERMCAP_se=\$'\\e[0m'
export LESS_TERMCAP_us=\$'\\e[1;32m'
export LESS_TERMCAP_ue=\$'\\e[0m'

# GCC 颜色
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
''';

    try {
      await bashrcFile.writeAsString(bashrcContent);
      debugPrint('Created bashrc at $bashrcPath');
    } catch (e) {
      debugPrint('Failed to create bashrc: $e');
    }
  }

  /// 创建 zshrc 配置文件
  static Future<void> _createZshrc() async {
    final zshrcPath = '${TermuxConstants.homeDir}/.zshrc';
    final zshrcFile = File(zshrcPath);

    // 如果已存在则不覆盖用户配置
    if (await zshrcFile.exists()) {
      return;
    }

    final zshrcContent = '''
# ~/.zshrc - Deep Thought Terminal Configuration for Zsh

# 历史记录配置
export HISTFILE="\$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=20000

# 历史记录选项
setopt APPEND_HISTORY        # 追加历史而不是覆盖
setopt INC_APPEND_HISTORY    # 每条命令后立即追加
setopt SHARE_HISTORY         # 多个终端共享历史
setopt HIST_IGNORE_DUPS      # 忽略连续重复命令
setopt HIST_IGNORE_SPACE     # 忽略以空格开头的命令
setopt HIST_REDUCE_BLANKS    # 删除多余空格
setopt EXTENDED_HISTORY      # 保存时间戳

# 提示符设置 - 绿色路径
PROMPT='%F{green}%~%f %# '

# 启用颜色支持
export CLICOLOR=1
export CLICOLOR_FORCE=1

# LS_COLORS 配置
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34:*.tar=1;31:*.gz=1;31:*.zip=1;31:*.7z=1;31:*.rar=1;31:*.jpg=1;35:*.jpeg=1;35:*.png=1;35:*.gif=1;35:*.bmp=1;35:*.mp3=1;36:*.mp4=1;36:*.mkv=1;36:*.avi=1;36:*.pdf=1;33:*.doc=1;33:*.txt=0;37'

# 常用命令别名 - 启用颜色
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'

# 便捷别名
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias q='exit'

# 让 less 支持颜色
export LESS='-R'

# GCC 颜色
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
''';

    try {
      await zshrcFile.writeAsString(zshrcContent);
      debugPrint('Created zshrc at $zshrcPath');
    } catch (e) {
      debugPrint('Failed to create zshrc: $e');
    }
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

    // 不需要包装的方法列表
    // 这些方法要么是简单的文件操作，要么是压缩工具，没有硬编码路径
    final skipMethods = {
      'store',    // 无压缩存储，APT 用作压缩器
      'copy',     // 简单复制
      'file',     // 本地文件访问
      'cdrom',    // CD-ROM 访问
      'gpgv',     // GPG 验证（单独处理）
      'bzip2',    // 压缩方法
      'gzip',     // 压缩方法
      'xz',       // 压缩方法
      'lzma',     // 压缩方法
      'lz4',      // 压缩方法
      'zstd',     // 压缩方法
    };

    // 恢复之前错误创建的 .real 文件
    // 如果存在 xxx.real 文件且 xxx 是包装脚本，则删除包装脚本并重命名回去
    for (final methodName in skipMethods) {
      final methodPath = '${methodsDir.path}/$methodName';
      final realPath = '${methodsDir.path}/$methodName.real';

      final realFile = File(realPath);
      if (await realFile.exists()) {
        // .real 文件存在，说明之前错误地创建了包装
        final methodFile = File(methodPath);
        if (await methodFile.exists()) {
          // 检查是否是包装脚本（非 ELF）
          final bytes = await methodFile.openRead(0, 4).first;
          final isElf = bytes.length >= 4 &&
              bytes[0] == 0x7f && bytes[1] == 0x45 &&
              bytes[2] == 0x4c && bytes[3] == 0x46;
          if (!isElf) {
            // 是包装脚本，删除它
            await methodFile.delete();
            debugPrint('Deleted wrapper script: $methodName');
          }
        }
        // 重命名 .real 回原名
        await realFile.rename(methodPath);
        debugPrint('Restored apt method: $methodName');
      }
    }

    // 第二步：先处理普通文件（创建 .real 和包装脚本）
    for (final fileName in regularFiles) {
      if (skipMethods.contains(fileName)) {
        debugPrint('Skipping apt method (no wrapper needed): $fileName');
        continue;
      }
      debugPrint('Processing apt method (file): $fileName');
      await _createAptMethodWrapper(fileName);
    }

    // 第三步：处理符号链接（此时目标的 .real 应该已存在）
    for (final fileName in symlinks) {
      if (skipMethods.contains(fileName)) {
        debugPrint('Skipping apt method symlink (no wrapper needed): $fileName');
        continue;
      }
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

      // 检查别名文件是否已存在且是最新版本
      final aliasFile = File(aliasPath);
      if (await aliasFile.exists()) {
        // 检查是否是有效的包装脚本（带有版本标记）
        try {
          final content = await aliasFile.readAsString();
          // 检查是否包含最新版本的标记（REQUESTS_CA_BUNDLE）
          if (content.contains('#!/system/bin/sh') &&
              content.contains(targetRealPath) &&
              content.contains('REQUESTS_CA_BUNDLE')) {
            debugPrint('Alias $aliasName already configured correctly');
            return;
          }
          debugPrint('Alias $aliasName exists but needs update');
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
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      final wrapperScript = '''#!/system/bin/sh
# APT method alias wrapper for Deep Thought terminal
# $aliasName -> $targetRealPath
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
export REQUESTS_CA_BUNDLE="$etcDir/tls/cert.pem"
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
          final binDir = TermuxConstants.binDir;
          final tmpDir = TermuxConstants.tmpDir;
          final etcDir = TermuxConstants.etcDir;

          final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
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
          final binDir = TermuxConstants.binDir;
          final tmpDir = TermuxConstants.tmpDir;
          final etcDir = TermuxConstants.etcDir;

          final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
exec "$realPath" "\$@"
''';

          await File(methodPath).writeAsString(wrapperScript);
          await Process.run('chmod', ['755', methodPath]);
          debugPrint('Created apt method wrapper for symlink $methodName (copied binary)');
        } else {
          // 目标可能是包装脚本，创建指向目标的包装
          final libDir = TermuxConstants.libDir;
          final binDir = TermuxConstants.binDir;
          final tmpDir = TermuxConstants.tmpDir;
          final etcDir = TermuxConstants.etcDir;

          // 尝试找到目标的 .real
          if (await targetRealFile.exists()) {
            final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
exec "$targetRealPath" "\$@"
''';
            await File(methodPath).writeAsString(wrapperScript);
          } else {
            // 直接调用目标（它应该是个包装脚本）
            final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
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
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"
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
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
export PATH="$binDir:/system/bin:/system/xbin"
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
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;

      final wrapperScript = '''#!/system/bin/sh
# Bash wrapper script for Deep Thought terminal
# The original bash has hardcoded paths to /data/data/com.termux/
# This wrapper sets correct library path and uses --norc to skip config files
export PATH="$binDir:/system/bin:/system/xbin"
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

      // dpkg 需要特殊处理 - 总是更新包装器以确保使用最新的补丁逻辑
      final forcedUpdate = (binaryName == 'dpkg');

      // 如果 .real 文件已存在，检查是否需要更新
      if (await realFile.exists()) {
        if (!forcedUpdate) {
          return;
        }
        // 强制更新：检查当前包装脚本是否是最新版本
        if (await binFile.exists()) {
          final content = await binFile.readAsString();
          // 如果包含最新的补丁逻辑标记，则不需要更新
          if (content.contains('dpkg-patch-v9')) {
            return;
          }
        }
        // 需要更新包装脚本，继续执行
        debugPrint('Updating $binaryName wrapper to latest version');
      } else {
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
      }

      // 创建包装脚本
      final libDir = TermuxConstants.libDir;
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      // APT 相关工具需要额外设置 APT_CONFIG 来覆盖硬编码路径
      final isAptTool = binaryName.startsWith('apt') || binaryName.startsWith('dpkg');
      final aptConfigExport = isAptTool
          ? 'export APT_CONFIG="$etcDir/apt/apt.conf"\n'
          : '';

      // update-alternatives 需要特殊处理：设置正确的目录路径
      if (binaryName == 'update-alternatives') {
        final varDir = TermuxConstants.varDir;
        final wrapperScript = '''#!/system/bin/sh
# update-alternatives wrapper for Deep Thought terminal
# Overrides hardcoded /data/data/com.termux/ paths
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"

ADMINDIR="$varDir/lib/dpkg/alternatives"
ALTDIR="$etcDir/alternatives"
LOGFILE="$varDir/log/alternatives.log"

# Create required directories
mkdir -p "\$ADMINDIR" 2>/dev/null
mkdir -p "\$ALTDIR" 2>/dev/null
mkdir -p "$varDir/log" 2>/dev/null

# Touch log file to ensure it exists
touch "\$LOGFILE" 2>/dev/null

exec "$realPath" --admindir "\$ADMINDIR" --altdir "\$ALTDIR" --log "\$LOGFILE" "\$@"
''';
        await binFile.writeAsString(wrapperScript);
        await Process.run('chmod', ['755', binPath]);
        debugPrint('Created special update-alternatives wrapper');
        return;
      }

      // dpkg 需要特殊处理：在安装前补丁 .deb 文件中的路径
      if (binaryName == 'dpkg') {
        final wrapperScript = '''#!/system/bin/sh
# dpkg wrapper that patches .deb files before installation
# Termux packages contain hardcoded /data/data/com.termux/ paths
# We need to extract, rename paths, and repack before installation
# Version: dpkg-patch-v9
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export APT_CONFIG="$etcDir/apt/apt.conf"

DPKG_REAL="$realPath"
LOGFILE="$tmpDir/dpkg-patch.log"

# Use dpkg-deb.real if available, otherwise use dpkg-deb
if [ -f "$binDir/dpkg-deb.real" ]; then
    DPKG_DEB_CMD="$binDir/dpkg-deb.real"
elif [ -f "$binDir/dpkg-deb" ]; then
    DPKG_DEB_CMD="$binDir/dpkg-deb"
else
    exec "\$DPKG_REAL" "\$@"
fi

# Function to patch a .deb file
patch_deb() {
    local debfile="\$1"

    if [ ! -f "\$debfile" ]; then
        return 1
    fi

    local tmpdir="\$TMPDIR/dpkg-patch-\$\$-\$RANDOM"
    mkdir -p "\$tmpdir/extract"

    # Extract the .deb
    "\$DPKG_DEB_CMD" -R "\$debfile" "\$tmpdir/extract" 2>> "\$LOGFILE"
    if [ \$? -ne 0 ]; then
        echo "\$(date): ERROR: Failed to extract \$debfile" >> "\$LOGFILE"
        rm -rf "\$tmpdir"
        return 1
    fi

    # Debug: show extracted structure
    echo "\$(date): Extracted \$debfile, structure:" >> "\$LOGFILE"
    find "\$tmpdir/extract" -type d 2>/dev/null | head -15 >> "\$LOGFILE"

    # Find and rename all com.termux directories to com.dpterm
    local found_termux=0
    local termux_dirs=\$(find "\$tmpdir/extract" -type d -name "com.termux" 2>/dev/null)

    if [ -n "\$termux_dirs" ]; then
        echo "\$(date): Found com.termux dirs: \$termux_dirs" >> "\$LOGFILE"
        for termux_dir in \$termux_dirs; do
            if [ -d "\$termux_dir" ]; then
                local parent_dir=\$(dirname "\$termux_dir")
                local target_dir="\$parent_dir/com.dpterm"
                mv "\$termux_dir" "\$target_dir" 2>> "\$LOGFILE"
                if [ \$? -eq 0 ]; then
                    found_termux=1
                    echo "\$(date): Renamed \$termux_dir -> \$target_dir" >> "\$LOGFILE"
                else
                    echo "\$(date): ERROR: Failed to rename \$termux_dir" >> "\$LOGFILE"
                fi
            fi
        done
    fi

    # Patch all files (binaries and scripts) that contain com.termux paths
    # Since com.termux and com.dpterm are same length (10 chars), binary patching is safe
    local patched_files=0
    for filepath in \$(find "\$tmpdir/extract" -type f 2>/dev/null); do
        if [ -f "\$filepath" ]; then
            # Check if file contains com.termux (binary-safe grep)
            if grep -q "com\.termux" "\$filepath" 2>/dev/null; then
                # Use LC_ALL=C sed for binary-safe replacement
                LC_ALL=C sed -i 's|com\.termux|com.dpterm|g' "\$filepath" 2>/dev/null
                patched_files=1
            fi
        fi
    done

    # Repack if we renamed directories OR patched files
    if [ \$found_termux -eq 1 ] || [ \$patched_files -eq 1 ]; then
        # Fix permissions on DEBIAN scripts
        # dpkg-deb requires maintainer scripts to have permissions >=0555 and <=0775
        if [ -d "\$tmpdir/extract/DEBIAN" ]; then
            chmod 755 "\$tmpdir/extract/DEBIAN"/* 2>/dev/null
        fi

        # Repack the .deb
        "\$DPKG_DEB_CMD" -b "\$tmpdir/extract" "\$tmpdir/patched.deb" 2>> "\$LOGFILE"
        if [ \$? -eq 0 ] && [ -f "\$tmpdir/patched.deb" ]; then
            # Make sure we can overwrite the original
            chmod 644 "\$debfile" 2>/dev/null
            cp "\$tmpdir/patched.deb" "\$debfile" 2>> "\$LOGFILE"
            if [ \$? -eq 0 ]; then
                echo "\$(date): Patched \$debfile (dirs:\$found_termux files:\$patched_files)" >> "\$LOGFILE"
            else
                echo "\$(date): ERROR: Failed to copy patched deb to \$debfile" >> "\$LOGFILE"
            fi
        else
            echo "\$(date): ERROR: Failed to repack \$debfile" >> "\$LOGFILE"
        fi
    fi

    rm -rf "\$tmpdir"
}

# Check for --recursive flag and directory argument
# APT calls: dpkg --recursive /path/to/dir (dir contains .deb files)
HAS_RECURSIVE=0
RECURSIVE_DIR=""
for arg in "\$@"; do
    if [ "\$arg" = "--recursive" ] || [ "\$arg" = "-R" ]; then
        HAS_RECURSIVE=1
    fi
    # Check if it's a directory (potential recursive target)
    if [ \$HAS_RECURSIVE -eq 1 ] && [ -d "\$arg" ]; then
        RECURSIVE_DIR="\$arg"
    fi
done

# If recursive mode with a directory, patch all .deb files in it
if [ \$HAS_RECURSIVE -eq 1 ] && [ -n "\$RECURSIVE_DIR" ] && [ -d "\$RECURSIVE_DIR" ]; then
    echo "\$(date): Recursive install from \$RECURSIVE_DIR" >> "\$LOGFILE"
    for debfile in "\$RECURSIVE_DIR"/*.deb; do
        if [ -f "\$debfile" ]; then
            patch_deb "\$debfile"
        fi
    done
fi

# Also check for direct .deb file arguments
for arg in "\$@"; do
    case "\$arg" in
        *.deb)
            if [ -f "\$arg" ]; then
                patch_deb "\$arg"
            fi
            ;;
    esac
done

exec "\$DPKG_REAL" "\$@"
''';
        await binFile.writeAsString(wrapperScript);
        await Process.run('chmod', ['755', binPath]);
        debugPrint('Created special dpkg wrapper with .deb patching');
        return;
      }

      final wrapperScript = '''#!/system/bin/sh
# Wrapper script to set correct library path
# The original binary has DT_RUNPATH pointing to /data/data/com.termux/
# This wrapper overrides it with the correct path
export PATH="$binDir:/system/bin:/system/xbin"
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

      // 补丁 termux-am (Android Activity Manager)
      // termux-am 是 DEX 文件，包含硬编码的 com.termux 包名
      await _patchTermuxAm();

      debugPrint('Hardcoded paths fixed');
    } catch (e) {
      debugPrint('Failed to fix hardcoded paths: $e');
    }
  }

  /// 补丁 termux-am 中的包名
  /// termux-am 使用 com.termux 作为 Android 包名发送 Intent
  /// 需要替换为实际的包名 com.dpterm
  static Future<void> _patchTermuxAm() async {
    // termux-am 可能在 bin 或 libexec 目录
    final possiblePaths = [
      '${TermuxConstants.binDir}/termux-am',
      '${TermuxConstants.libexecDir}/termux-am',
      '${TermuxConstants.binDir}/am',
    ];

    const oldPackage = 'com.termux';
    const newPackage = 'com.dpterm';

    // 验证长度相同（二进制安全替换需要）
    if (oldPackage.length != newPackage.length) {
      debugPrint('ERROR: Package name lengths do not match!');
      return;
    }

    for (final path in possiblePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      try {
        final bytes = await file.readAsBytes();
        final oldBytes = Uint8List.fromList(oldPackage.codeUnits);
        final newBytes = Uint8List.fromList(newPackage.codeUnits);

        // 查找并替换所有出现的 com.termux
        int patchCount = 0;
        for (int i = 0; i <= bytes.length - oldBytes.length; i++) {
          bool match = true;
          for (int j = 0; j < oldBytes.length; j++) {
            if (bytes[i + j] != oldBytes[j]) {
              match = false;
              break;
            }
          }
          if (match) {
            for (int j = 0; j < newBytes.length; j++) {
              bytes[i + j] = newBytes[j];
            }
            patchCount++;
            i += oldBytes.length - 1; // 跳过已替换的部分
          }
        }

        if (patchCount > 0) {
          await file.writeAsBytes(bytes);
          debugPrint('Patched $path: replaced $patchCount occurrences of $oldPackage');
        }
      } catch (e) {
        debugPrint('Failed to patch $path: $e');
      }
    }

    // 同时补丁 termux-am 相关的脚本包装器
    await _patchTermuxAmScripts();
  }

  /// 补丁 termux-am 相关脚本中的包名引用
  static Future<void> _patchTermuxAmScripts() async {
    final scriptsToCheck = [
      '${TermuxConstants.binDir}/chsh',
      '${TermuxConstants.binDir}/termux-reload-settings',
      '${TermuxConstants.binDir}/termux-open',
      '${TermuxConstants.binDir}/termux-open-url',
      '${TermuxConstants.binDir}/termux-share',
      '${TermuxConstants.binDir}/termux-toast',
      '${TermuxConstants.binDir}/termux-vibrate',
      '${TermuxConstants.binDir}/termux-notification',
      '${TermuxConstants.binDir}/termux-tts-speak',
      '${TermuxConstants.binDir}/termux-clipboard-set',
      '${TermuxConstants.binDir}/termux-clipboard-get',
    ];

    const replacements = {
      'com.termux': 'com.dpterm',
      'com.termux.app': 'com.dpterm.app',
      'com.termux.api': 'com.dpterm.api',
    };

    for (final scriptPath in scriptsToCheck) {
      final file = File(scriptPath);
      if (!await file.exists()) continue;

      try {
        var content = await file.readAsString();
        bool modified = false;

        for (final entry in replacements.entries) {
          if (content.contains(entry.key)) {
            content = content.replaceAll(entry.key, entry.value);
            modified = true;
          }
        }

        if (modified) {
          await file.writeAsString(content);
          debugPrint('Patched script: $scriptPath');
        }
      } catch (e) {
        // 可能是二进制文件，跳过
      }
    }
  }

  /// 修复脚本的 shebang 行
  /// 因为我们的 bash 是包装脚本，不能被内核直接用作解释器
  /// 需要将 shebang 改为使用 bash-real 或 /system/bin/sh
  static Future<void> _fixScriptShebangs() async {
    debugPrint('Fixing script shebangs...');

    final binDir = TermuxConstants.binDir;
    final bashPath = '$binDir/bash';
    final bashRealPath = '$binDir/bash-real';
    final shPath = '$binDir/sh';

    // 首先修复 sh 符号链接 - 它应该指向 bash-real 而不是 bash
    await _fixShSymlink();

    // 需要修复 shebang 的目录列表
    final dirsToFix = [
      TermuxConstants.binDir,
      TermuxConstants.libexecDir,
      '${TermuxConstants.libDir}/apt',
      '${TermuxConstants.shareDir}',
    ];

    // shebang 替换规则：
    // #!/.../bash -> #!/.../bash-real (保持bash特性)
    // #!/.../sh -> #!/.../bash-real (sh 通常是 bash 的别名)
    // 或者对于简单脚本使用 /system/bin/sh
    final shebangReplacements = {
      // bash shebangs
      '#!$bashPath\n': '#!$bashRealPath\n',
      '#!$bashPath ': '#!$bashRealPath ',
      '#!$bashPath\r': '#!$bashRealPath\r',
      // sh shebangs - 使用 bash-real
      '#!$shPath\n': '#!$bashRealPath\n',
      '#!$shPath ': '#!$bashRealPath ',
      '#!$shPath\r': '#!$bashRealPath\r',
      // 也处理可能的旧路径（以防万一）
      '#!/data/data/com.termux/files/usr/bin/bash\n': '#!$bashRealPath\n',
      '#!/data/data/com.termux/files/usr/bin/bash ': '#!$bashRealPath ',
      '#!/data/data/com.termux/files/usr/bin/sh\n': '#!$bashRealPath\n',
      '#!/data/data/com.termux/files/usr/bin/sh ': '#!$bashRealPath ',
    };

    int fixedCount = 0;

    for (final dirPath in dirsToFix) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;

          try {
            // 读取文件开头检查是否是脚本
            final bytes = await entity.openRead(0, 256).first;
            if (bytes.length < 2) continue;

            // 检查是否有 shebang
            if (bytes[0] != 0x23 || bytes[1] != 0x21) continue; // #!

            // 跳过 ELF 文件
            if (bytes.length >= 4 &&
                bytes[0] == 0x7f && bytes[1] == 0x45 &&
                bytes[2] == 0x4c && bytes[3] == 0x46) {
              continue;
            }

            // 读取文件内容
            final content = await entity.readAsString();

            // 检查是否需要修复 shebang
            bool needsFix = false;
            var newContent = content;

            for (final entry in shebangReplacements.entries) {
              if (content.startsWith(entry.key)) {
                newContent = entry.value + content.substring(entry.key.length);
                needsFix = true;
                break;
              }
            }

            if (needsFix) {
              await entity.writeAsString(newContent);
              fixedCount++;
              debugPrint('Fixed shebang: ${entity.path}');
            }
          } catch (e) {
            // 跳过无法读取的文件
          }
        }
      } catch (e) {
        debugPrint('Error fixing shebangs in $dirPath: $e');
      }
    }

    debugPrint('Fixed $fixedCount script shebangs');
  }

  /// 修复 sh 符号链接
  /// sh 通常是指向 bash 的符号链接，但 bash 现在是包装脚本
  /// 需要让 sh 指向 bash-real 以便脚本可以正常执行
  static Future<void> _fixShSymlink() async {
    final binDir = TermuxConstants.binDir;
    final shPath = '$binDir/sh';
    final bashRealPath = '$binDir/bash-real';

    try {
      final shEntity = await FileSystemEntity.type(shPath, followLinks: false);

      if (shEntity == FileSystemEntityType.link) {
        // 检查当前指向
        final link = Link(shPath);
        final target = await link.target();

        // 如果已经指向 bash-real，不需要修改
        if (target == 'bash-real' || target == bashRealPath) {
          debugPrint('sh symlink already points to bash-real');
          return;
        }

        // 删除旧链接，创建新链接指向 bash-real
        await link.delete();
        await Link(shPath).create('bash-real');
        debugPrint('Fixed sh symlink: now points to bash-real');
      } else if (shEntity == FileSystemEntityType.file) {
        // sh 是文件（可能是包装脚本或二进制）
        // 检查是否是 ELF
        final file = File(shPath);
        final bytes = await file.openRead(0, 4).first;
        if (bytes.length >= 4 &&
            bytes[0] == 0x7f && bytes[1] == 0x45 &&
            bytes[2] == 0x4c && bytes[3] == 0x46) {
          // 是 ELF 二进制，保持不变
          debugPrint('sh is an ELF binary, keeping as is');
        } else {
          // 是脚本，替换为符号链接
          await file.delete();
          await Link(shPath).create('bash-real');
          debugPrint('Replaced sh script with symlink to bash-real');
        }
      } else {
        // sh 不存在，创建符号链接
        await Link(shPath).create('bash-real');
        debugPrint('Created sh symlink to bash-real');
      }
    } catch (e) {
      debugPrint('Failed to fix sh symlink: $e');
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

  /// 安装 GPG 密钥环
  /// 将 share/termux-keyring/*.gpg 复制/链接到 etc/apt/trusted.gpg.d/
  static Future<void> _installGpgKeyring() async {
    debugPrint('Installing GPG keyring...');

    final shareDir = TermuxConstants.shareDir;
    final etcDir = TermuxConstants.etcDir;
    final keyringSourceDir = Directory('$shareDir/termux-keyring');
    final trustedGpgDir = Directory('$etcDir/apt/trusted.gpg.d');

    try {
      // 确保目标目录存在
      if (!await trustedGpgDir.exists()) {
        await trustedGpgDir.create(recursive: true);
      }

      // 检查源目录是否存在
      if (!await keyringSourceDir.exists()) {
        debugPrint('GPG keyring source directory not found: ${keyringSourceDir.path}');
        return;
      }

      int installedKeys = 0;

      // 复制所有 .gpg 文件到 trusted.gpg.d
      await for (final entity in keyringSourceDir.list(followLinks: false)) {
        if (entity is! File) continue;

        final fileName = path.basename(entity.path);
        if (!fileName.endsWith('.gpg')) continue;

        final targetPath = '${trustedGpgDir.path}/$fileName';
        final targetFile = File(targetPath);

        // 检查目标是否已存在
        if (await targetFile.exists()) {
          debugPrint('GPG key already exists: $fileName');
          installedKeys++;
          continue;
        }

        // 复制密钥文件
        try {
          await entity.copy(targetPath);
          debugPrint('Installed GPG key: $fileName');
          installedKeys++;
        } catch (e) {
          debugPrint('Failed to install GPG key $fileName: $e');
        }
      }

      debugPrint('GPG keyring installation complete: $installedKeys keys installed');
    } catch (e) {
      debugPrint('Failed to install GPG keyring: $e');
    }
  }

  /// 配置APT包管理器
  static Future<void> _configureApt() async {
    try {
      final prefixDir = TermuxConstants.prefixDir;
      final etcDir = TermuxConstants.etcDir;
      final varDir = TermuxConstants.varDir;

      debugPrint('Configuring APT...');
      debugPrint('  PREFIX: $prefixDir');
      debugPrint('  ETC: $etcDir');
      debugPrint('  VAR: $varDir');

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

      // 安装 GPG 密钥到 trusted.gpg.d
      await _installGpgKeyring();

      // 创建 apt.conf 覆盖所有硬编码路径
      final aptConfFile = File('$etcDir/apt/apt.conf');
      final caCertFile = '$etcDir/tls/cert.pem';
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

// SSL/TLS certificate configuration for HTTPS
// GnuTLS has hardcoded certificate paths, but we patch the binary
// to use our certificate file via a short symlink path
Acquire::https::CaInfo "$caCertFile";
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";
''';
      await aptConfFile.writeAsString(aptConfContent);
      debugPrint('APT apt.conf configured at: ${aptConfFile.path}');

      // 验证证书文件是否存在
      final certFile = File(caCertFile);
      if (await certFile.exists()) {
        final certSize = await certFile.length();
        debugPrint('CA certificate file exists: $caCertFile (${certSize} bytes)');
      } else {
        debugPrint('WARNING: CA certificate file NOT found: $caCertFile');
      }

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

      // 检查是否需要更新 pkg 脚本
      // 总是重新创建以确保包含最新的配置
      if (await pkgFile.exists()) {
        final content = await pkgFile.readAsString();
        // 检查是否包含最新版本的功能（v3: GnuTLS patch check）
        if (content.contains('Deep Thought') &&
            content.contains('show_debug') &&
            content.contains('GnuTLS patch status')) {
          debugPrint('pkg script already up to date');
          return;
        }
        debugPrint('Updating pkg script...');
      }

      // 创建pkg脚本
      final libDir = TermuxConstants.libDir;
      final prefixDir = TermuxConstants.prefixDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      final pkgScript = '''#!/system/bin/sh
# pkg - Package manager wrapper for Deep Thought terminal
# Simplified version inspired by Termux

export LD_LIBRARY_PATH="$libDir"
export PREFIX="$prefixDir"
export TMPDIR="$tmpDir"
export APT_CONFIG="$etcDir/apt/apt.conf"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
export CURL_CA_BUNDLE="$etcDir/tls/cert.pem"

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
    echo "  debug            - Show debug information"
    echo ""
    echo "Examples:"
    echo "  pkg update"
    echo "  pkg install git"
    echo "  pkg search python"
}

show_debug() {
    echo "=== Deep Thought Package Manager Debug Info ==="
    echo ""
    echo "Environment:"
    echo "  PREFIX=\$PREFIX"
    echo "  APT_CONFIG=\$APT_CONFIG"
    echo "  SSL_CERT_FILE=\$SSL_CERT_FILE"
    echo "  LD_LIBRARY_PATH=\$LD_LIBRARY_PATH"
    echo ""
    echo "Checking files:"
    if [ -f "\$APT_CONFIG" ]; then
        echo "  [OK] apt.conf exists"
        echo "  Content (SSL/TLS settings):"
        grep -iE "cainfo|verify|insecure" "\$APT_CONFIG" 2>/dev/null || echo "    (no SSL settings found)"
    else
        echo "  [ERROR] apt.conf NOT found: \$APT_CONFIG"
    fi
    echo ""
    if [ -f "\$SSL_CERT_FILE" ]; then
        SIZE=\$(ls -l "\$SSL_CERT_FILE" | awk '{print \$5}')
        PERMS=\$(ls -l "\$SSL_CERT_FILE" | awk '{print \$1}')
        echo "  [OK] cert.pem exists (\$SIZE bytes, \$PERMS)"
    else
        echo "  [ERROR] cert.pem NOT found: \$SSL_CERT_FILE"
    fi
    echo ""
    echo "APT methods:"
    ls -la "$libDir/apt/methods/" 2>/dev/null || echo "  [ERROR] methods dir not found"
    echo ""
    echo "HTTPS method wrapper:"
    if [ -f "$libDir/apt/methods/https" ]; then
        cat "$libDir/apt/methods/https"
    else
        echo "  [ERROR] https method not found"
    fi
    echo ""
    echo "HTTP.real exists:"
    ls -la "$libDir/apt/methods/http.real" 2>/dev/null || echo "  [ERROR] http.real not found"
    echo ""
    echo "APT config dump (SSL/TLS):"
    apt-config dump 2>/dev/null | grep -iE "cainfo|cert|ssl|https|verify|insecure" || echo "  (no SSL config found)"
    echo ""
    echo "GnuTLS patch status:"
    SHORTCERT="\$PREFIX/../c"
    if [ -L "\$SHORTCERT" ]; then
        TARGET=\$(readlink "\$SHORTCERT")
        echo "  [OK] Short cert symlink exists: \$SHORTCERT -> \$TARGET"
    else
        echo "  [ERROR] Short cert symlink NOT found: \$SHORTCERT"
    fi
    echo ""
    echo "libgnutls.so patch check:"
    GNUTLS_LIB=\$(ls "$libDir"/libgnutls.so* 2>/dev/null | head -1)
    if [ -n "\$GNUTLS_LIB" ]; then
        if strings "\$GNUTLS_LIB" 2>/dev/null | grep -q "com.dpterm"; then
            echo "  [OK] libgnutls.so is patched (contains com.dpterm path)"
        elif strings "\$GNUTLS_LIB" 2>/dev/null | grep -q "com.termux"; then
            echo "  [WARNING] libgnutls.so NOT patched (still contains com.termux path)"
        else
            echo "  [UNKNOWN] Could not determine patch status"
        fi
    else
        echo "  [ERROR] libgnutls.so not found"
    fi
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
    debug|diag)
        show_debug
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

  /// 创建 setup-storage 脚本
  /// 类似 Termux 的 termux-setup-storage 功能
  static Future<void> createSetupStorageScript() async {
    final scriptPath = '${TermuxConstants.binDir}/setup-storage';

    try {
      final scriptFile = File(scriptPath);

      // 检查是否已存在
      if (await scriptFile.exists()) {
        final content = await scriptFile.readAsString();
        if (content.contains('Deep Thought Storage Setup')) {
          debugPrint('setup-storage script already exists');
          return;
        }
      }

      // OSC 52 是剪贴板操作，我们使用自定义 OSC 序列来触发存储设置
      // 使用 OSC 7777 作为自定义命令（避免与标准序列冲突）
      // 格式: ESC ] 7777 ; setup-storage BEL
      final script = r'''#!/system/bin/sh
# setup-storage - Storage setup for Deep Thought terminal
# Similar to Termux's termux-setup-storage

echo "Deep Thought Storage Setup"
echo ""
echo "This will set up access to external storage."
echo "A permission dialog will be shown if needed."
echo ""
echo "The following symlinks will be created in ~/storage:"
echo "  shared    -> External storage root (/sdcard)"
echo "  downloads -> Downloads directory"
echo "  dcim      -> DCIM (photos/videos)"
echo "  pictures  -> Pictures directory"
echo "  music     -> Music directory"
echo "  movies    -> Movies directory"
echo "  documents -> Documents directory"
echo "  external-N -> App-specific external storage"
echo "  media-N   -> App-specific media storage"
echo ""

# 发送 OSC 序列触发 Flutter 处理存储权限
# ESC ] 7777 ; setup-storage BEL
printf '\033]7777;setup-storage\007'

# 给用户一些反馈
echo "Requesting storage permission..."
echo "Please grant access in the system dialog if prompted."
echo ""
echo "Note: If using Android 11+, you need to enable"
echo "'Allow access to manage all files' in settings."
''';

            await scriptFile.writeAsString(script);

            await Process.run('chmod', ['755', scriptPath]);

      

            // Also overwrite termux-setup-storage

            final termuxScriptPath = '${TermuxConstants.binDir}/termux-setup-storage';

            await File(termuxScriptPath).writeAsString(script);

            await Process.run('chmod', ['755', termuxScriptPath]);

      

            debugPrint('setup-storage and termux-setup-storage scripts created');

          } catch (e) {
      debugPrint('Failed to create setup-storage script: $e');
    }
  }

  /// 创建 chsh 替代脚本
  /// 原版 chsh 依赖 termux-am 广播，这里改为直接修改 shell 配置
  static Future<void> _createChshScript() async {
    final chshPath = '${TermuxConstants.binDir}/chsh';
    final homeDir = TermuxConstants.homeDir;
    final binDir = TermuxConstants.binDir;

    try {
      final chshScript = '''#!/system/bin/sh
# chsh - Change login shell for Deep Thought terminal
# This is a replacement that doesn't require termux-am broadcasts

SHELL_CONFIG="$homeDir/.shell"
BASHRC="$homeDir/.bashrc"
PROFILE="$homeDir/.profile"

show_help() {
    echo "Usage: chsh [-s shell]"
    echo ""
    echo "Options:"
    echo "  -s shell    Specify the new login shell"
    echo "  -h          Show this help message"
    echo ""
    echo "Available shells:"
    for shell in $binDir/bash $binDir/zsh $binDir/fish $binDir/sh; do
        if [ -x "\$shell" ]; then
            echo "  \$shell"
        fi
    done
    echo ""
    echo "Note: Changes take effect on next terminal session"
}

# Parse arguments
NEW_SHELL=""
while [ \$# -gt 0 ]; do
    case "\$1" in
        -s)
            shift
            NEW_SHELL="\$1"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            # Assume it's the shell name if not starting with -
            if [ -z "\$NEW_SHELL" ]; then
                NEW_SHELL="\$1"
            fi
            ;;
    esac
    shift
done

if [ -z "\$NEW_SHELL" ]; then
    show_help
    exit 1
fi

# Resolve shell path
case "\$NEW_SHELL" in
    bash|/*/bash)
        SHELL_PATH="$binDir/bash"
        ;;
    zsh|/*/zsh)
        SHELL_PATH="$binDir/zsh"
        ;;
    fish|/*/fish)
        SHELL_PATH="$binDir/fish"
        ;;
    sh|/*/sh)
        SHELL_PATH="$binDir/sh"
        ;;
    /*)
        SHELL_PATH="\$NEW_SHELL"
        ;;
    *)
        SHELL_PATH="$binDir/\$NEW_SHELL"
        ;;
esac

# Check if shell exists
if [ ! -x "\$SHELL_PATH" ]; then
    echo "Error: Shell '\$SHELL_PATH' not found or not executable"
    exit 1
fi

# Save the shell preference
echo "\$SHELL_PATH" > "\$SHELL_CONFIG"
chmod 600 "\$SHELL_CONFIG"

# Also update .bashrc to exec the new shell (for compatibility)
SHELL_NAME=\$(basename "\$SHELL_PATH")
if [ "\$SHELL_NAME" != "bash" ]; then
    # Create shell config file if it doesn't exist
    if [ "\$SHELL_NAME" = "zsh" ] && [ ! -f "$homeDir/.zshrc" ]; then
        echo "Creating default .zshrc..."
        cat > "$homeDir/.zshrc" << 'ZSHRC_EOF'
# ~/.zshrc - Deep Thought Terminal Configuration for Zsh

# 历史记录配置
export HISTFILE="\$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=20000

# 历史记录选项
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY

# 提示符设置
PROMPT='%F{green}%~%f %# '

# 颜色支持
export CLICOLOR=1
export CLICOLOR_FORCE=1
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33'

# 别名
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias c='clear'
alias h='history'
ZSHRC_EOF
    fi

    # Check if exec line already exists
    if ! grep -q "^exec.*\$SHELL_NAME" "\$BASHRC" 2>/dev/null; then
        # Remove any existing exec lines for other shells
        if [ -f "\$BASHRC" ]; then
            sed -i '/^exec.*\\(zsh\\|fish\\)/d' "\$BASHRC" 2>/dev/null
        fi
        # Add exec line at the end
        echo "" >> "\$BASHRC"
        echo "# Auto-start \$SHELL_NAME (set by chsh)" >> "\$BASHRC"
        echo "exec \$SHELL_PATH" >> "\$BASHRC"
    fi
    echo "Shell changed to \$SHELL_PATH"
    echo "Note: The change will take effect on next terminal session"
else
    # Bash selected, remove any exec lines
    if [ -f "\$BASHRC" ]; then
        sed -i '/^exec.*\\(zsh\\|fish\\)/d' "\$BASHRC" 2>/dev/null
        sed -i '/^# Auto-start.*set by chsh/d' "\$BASHRC" 2>/dev/null
    fi
    echo "Shell changed to bash"
fi
''';

      await File(chshPath).writeAsString(chshScript);
      await Process.run('chmod', ['755', chshPath]);
      debugPrint('chsh script created');
    } catch (e) {
      debugPrint('Failed to create chsh script: $e');
    }
  }

  /// 创建 termux-reload-settings 脚本
  /// 通过创建信号文件通知 Flutter 应用重载设置
  static Future<void> _createTermuxReloadSettingsScript() async {
    final scriptPath = '${TermuxConstants.binDir}/termux-reload-settings';
    final homeDir = TermuxConstants.homeDir;

    try {
      final script = '''#!/system/bin/sh
# termux-reload-settings - Reload terminal settings
# Deep Thought implementation using signal file mechanism

TERMUX_CONFIG_DIR="$homeDir/.termux"
SIGNAL_FILE="\$TERMUX_CONFIG_DIR/.reload-settings"
PROPS_FILE="\$TERMUX_CONFIG_DIR/termux.properties"

# Ensure config directory exists
mkdir -p "\$TERMUX_CONFIG_DIR" 2>/dev/null

# Create signal file to notify the app
touch "\$SIGNAL_FILE"

echo "Settings reload requested."

# Check if properties file exists
if [ -f "\$PROPS_FILE" ]; then
    echo "Loading settings from: \$PROPS_FILE"
else
    echo "Note: No termux.properties file found."
    echo "Create \$PROPS_FILE to customize settings."
    echo ""
    echo "Example settings:"
    echo "  terminal-font-size=14"
    echo "  terminal-cursor-style=block"
    echo "  extra-keys=true"
    echo "  bell-character=vibrate"
fi

echo ""
echo "Settings will be applied shortly..."
exit 0
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['755', scriptPath]);
      debugPrint('termux-reload-settings script created');
    } catch (e) {
      debugPrint('Failed to create termux-reload-settings script: $e');
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

  /// 补丁 dpkg info 文件中的硬编码路径
  /// dpkg 的 .list 文件记录了已安装包的文件路径
  /// 这些路径包含 /data/data/com.termux/，需要替换为正确的路径
  static Future<void> _patchDpkgInfoFiles() async {
    debugPrint('Patching dpkg info files...');

    const oldPath = '/data/data/com.termux/';
    final newPath = '/data/data/${AppConstants.packageName}/';

    final dpkgInfoDir = Directory('${TermuxConstants.varDir}/lib/dpkg/info');
    if (!await dpkgInfoDir.exists()) {
      debugPrint('dpkg info directory does not exist, skipping');
      return;
    }

    int patchedFiles = 0;
    int patchedLines = 0;

    try {
      await for (final entity in dpkgInfoDir.list()) {
        if (entity is File) {
          final filename = entity.path.split('/').last;
          // 补丁 .list 文件（记录包文件路径）和 .conffiles 文件
          if (filename.endsWith('.list') || filename.endsWith('.conffiles')) {
            try {
              final content = await entity.readAsString();
              if (content.contains(oldPath)) {
                final newContent = content.replaceAll(oldPath, newPath);
                await entity.writeAsString(newContent);
                final lineCount = oldPath.allMatches(content).length;
                patchedFiles++;
                patchedLines += lineCount;
              }
            } catch (e) {
              debugPrint('Failed to patch ${entity.path}: $e');
            }
          }
        }
      }

      debugPrint('Patched $patchedFiles dpkg info files ($patchedLines path entries)');
    } catch (e) {
      debugPrint('Failed to patch dpkg info files: $e');
    }
  }

  /// 补丁二进制文件中的硬编码路径
  /// Termux 二进制文件中硬编码了 /data/data/com.termux/ 路径
  /// 我们的包名 com.dpterm 与 com.termux 长度相同（10字符），可以直接替换
  static Future<void> _patchBinaryPaths() async {
    debugPrint('Patching binary paths...');

    // 原始路径和新路径（长度必须相同）
    const oldPath = '/data/data/com.termux/';
    final newPath = '/data/data/${AppConstants.packageName}/';

    // 验证长度相同
    if (oldPath.length != newPath.length) {
      debugPrint('ERROR: Path lengths do not match! Old: ${oldPath.length}, New: ${newPath.length}');
      return;
    }

    debugPrint('Patching: "$oldPath" -> "$newPath"');

    int totalPatched = 0;
    int totalSkipped = 0;

    // 需要补丁的库文件 (在 lib 目录)
    final librariesToPatch = [
      'libgnutls.so',
      'libapt-pkg.so',
      'libapt-private.so',
      'libcurl.so',
    ];

    // 需要补丁的二进制文件 (在 bin 目录)
    // 这些二进制文件中可能有硬编码的配置路径
    final binariesToPatch = [
      'dpkg',
      'dpkg-deb',
      'dpkg-query',
      'dpkg-split',
      'dpkg-trigger',
      'apt',
      'apt-get',
      'apt-cache',
      'apt-config',
      'apt-mark',
      'apt-ftparchive',
      'apt-sortpkgs',
      'update-alternatives',
    ];

    try {
      // 补丁 lib 目录中的库文件
      final libDir = Directory(TermuxConstants.libDir);
      if (await libDir.exists()) {
        final result = await _patchFilesInDirectory(
          libDir,
          librariesToPatch,
          oldPath,
          newPath,
          matchPrefix: true,
        );
        totalPatched += result['patched'] as int;
        totalSkipped += result['skipped'] as int;
      }

      // 补丁 bin 目录中的二进制文件
      // 注意: 可能是原始文件或 .real 文件（取决于是否已创建包装脚本）
      final binDir = Directory(TermuxConstants.binDir);
      if (await binDir.exists()) {
        // 首先尝试补丁 .real 文件（如果已经创建了包装脚本）
        final realBinaries = binariesToPatch.map((b) => '$b.real').toList();
        var result = await _patchFilesInDirectory(
          binDir,
          realBinaries,
          oldPath,
          newPath,
          matchPrefix: false,
        );
        totalPatched += result['patched'] as int;
        totalSkipped += result['skipped'] as int;

        // 然后补丁原始二进制文件（如果还没有创建包装脚本）
        result = await _patchFilesInDirectory(
          binDir,
          binariesToPatch,
          oldPath,
          newPath,
          matchPrefix: false,
        );
        totalPatched += result['patched'] as int;
        totalSkipped += result['skipped'] as int;
      }

      // 补丁 lib/apt/methods 目录中的 APT 方法二进制
      // 只补丁 http 方法（它有硬编码的证书路径）
      // store, copy, file, gpgv 等方法不需要补丁
      final aptMethodsDir = Directory('${TermuxConstants.libDir}/apt/methods');
      if (await aptMethodsDir.exists()) {
        // 只补丁 http 和 https 方法（有硬编码路径）
        final aptMethods = ['http.real', 'http'];
        var result = await _patchFilesInDirectory(
          aptMethodsDir,
          aptMethods,
          oldPath,
          newPath,
          matchPrefix: false,
        );
        totalPatched += result['patched'] as int;
        totalSkipped += result['skipped'] as int;
      }

      debugPrint('Binary patching complete: $totalPatched patched, $totalSkipped skipped');
    } catch (e) {
      debugPrint('Failed to patch binary paths: $e');
    }
  }

  /// 补丁指定目录中的文件
  static Future<Map<String, int>> _patchFilesInDirectory(
    Directory dir,
    List<String> filePatterns,
    String oldPath,
    String newPath, {
    bool matchPrefix = true,
  }) async {
    int patchedFiles = 0;
    int skippedFiles = 0;

    final oldPathBytes = oldPath.codeUnits;
    final newPathBytes = newPath.codeUnits;

    await for (final entity in dir.list(followLinks: false)) {
      final fileName = path.basename(entity.path);

      // 检查是否是需要补丁的文件
      bool shouldPatch = false;
      for (final pattern in filePatterns) {
        if (matchPrefix) {
          if (fileName.startsWith(pattern)) {
            shouldPatch = true;
            break;
          }
        } else {
          if (fileName == pattern) {
            shouldPatch = true;
            break;
          }
        }
      }

      if (!shouldPatch) continue;

      final file = File(entity.path);
      if (!await file.exists()) continue;

      // 检查是否是 ELF 文件
      final bytes = await file.readAsBytes();
      if (bytes.length < 4 ||
          bytes[0] != 0x7f ||
          bytes[1] != 0x45 ||
          bytes[2] != 0x4c ||
          bytes[3] != 0x46) {
        continue; // 不是 ELF 文件
      }

      // 检查是否已经补丁过
      if (_containsPattern(bytes, newPathBytes)) {
        debugPrint('Already patched: $fileName');
        skippedFiles++;
        continue;
      }

      // 检查是否包含旧路径
      if (!_containsPattern(bytes, oldPathBytes)) {
        continue; // 不包含旧路径，跳过
      }

      // 查找并替换所有出现的旧路径
      bool modified = false;
      final newBytes = Uint8List.fromList(bytes);

      for (int i = 0; i <= newBytes.length - oldPathBytes.length; i++) {
        bool match = true;
        for (int j = 0; j < oldPathBytes.length; j++) {
          if (newBytes[i + j] != oldPathBytes[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          // 替换
          for (int j = 0; j < newPathBytes.length; j++) {
            newBytes[i + j] = newPathBytes[j];
          }
          modified = true;
        }
      }

      if (modified) {
        // 备份原文件
        final backupPath = '${entity.path}.orig';
        final backupFile = File(backupPath);
        if (!await backupFile.exists()) {
          await file.copy(backupPath);
        }

        // 写入修改后的文件
        await file.writeAsBytes(newBytes);
        debugPrint('Patched: $fileName');
        patchedFiles++;
      }
    }

    return {'patched': patchedFiles, 'skipped': skippedFiles};
  }

  /// 检查字节数组是否包含指定模式
  static bool _containsPattern(List<int> data, List<int> pattern) {
    if (pattern.isEmpty || data.length < pattern.length) {
      return false;
    }

    for (int i = 0; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) {
        return true;
      }
    }
    return false;
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
    // CA 证书路径 - 用于 SSL/TLS 证书验证
    final caCertFile = '${TermuxConstants.etcDir}/tls/cert.pem';
    // APT 配置文件路径
    final aptConfFile = '${TermuxConstants.etcDir}/apt/apt.conf';

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
      'ANDROID_ROOT': '/system',
      'ANDROID_DATA': '/data',
      // APT 配置 - 告诉 APT 使用我们的配置文件
      'APT_CONFIG': aptConfFile,
      // SSL/TLS 证书配置 - 用于 HTTPS 连接验证
      'SSL_CERT_FILE': caCertFile,
      'CURL_CA_BUNDLE': caCertFile,
      'GIT_SSL_CAINFO': caCertFile,
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
