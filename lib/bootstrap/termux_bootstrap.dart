import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';

/// 耗时统计工具
class BootstrapProfiler {
  static final Map<String, int> _timings = {};
  static final Map<String, Stopwatch> _stopwatches = {};
  static bool enabled = true;  // 设置为 false 可禁用统计

  static void start(String name) {
    if (!enabled) return;
    _stopwatches[name] = Stopwatch()..start();
  }

  static void end(String name) {
    if (!enabled) return;
    final sw = _stopwatches[name];
    if (sw != null) {
      sw.stop();
      _timings[name] = sw.elapsedMilliseconds;
    }
  }

  static void reset() {
    _timings.clear();
    _stopwatches.clear();
  }

  static String getReport() {
    if (_timings.isEmpty) return 'No profiling data';

    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════════════════╗');
    buffer.writeln('║           Bootstrap 初始化耗时分析报告                        ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════╣');

    // 按耗时排序
    final sorted = _timings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int total = 0;
    for (final entry in sorted) {
      total += entry.value;
      final name = entry.key.padRight(40);
      final time = '${entry.value} ms'.padLeft(10);
      buffer.writeln('║ $name $time    ║');
    }

    buffer.writeln('╠══════════════════════════════════════════════════════════════╣');
    final totalStr = '$total ms'.padLeft(10);
    buffer.writeln('║ ${'总计'.padRight(40)} $totalStr    ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════╝');

    return buffer.toString();
  }

  static void printReport() {
    debugPrint(getReport());
  }
}

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
/// 注意：bootstrap 已使用正确的包名（com.dpterm）编译，无需路径补丁
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
    BootstrapProfiler.reset();
    BootstrapProfiler.start('总初始化时间');

    try {
      // 检查是否已安装
      BootstrapProfiler.start('检查是否已安装');
      final alreadyInstalled = await isInstalled();
      BootstrapProfiler.end('检查是否已安装');

      if (alreadyInstalled) {
        _status = BootstrapStatus.configuring;
        onProgress?.call(_status, 0.9, 'Updating configuration...');

        // 即使已安装，也要更新配置
        await _configureEnvironment();

        _status = BootstrapStatus.installed;
        onProgress?.call(_status, 1.0, 'Bootstrap ready');

        BootstrapProfiler.end('总初始化时间');
        BootstrapProfiler.printReport();
        return true;
      }

      // 创建基础目录结构
      _status = BootstrapStatus.configuring;
      onProgress?.call(_status, 0.05, 'Creating directories...');
      BootstrapProfiler.start('创建目录结构');
      await _createDirectories();
      BootstrapProfiler.end('创建目录结构');

      // 从assets加载Bootstrap包
      _status = BootstrapStatus.loading;
      onProgress?.call(_status, 0.1, 'Loading bootstrap from assets...');
      BootstrapProfiler.start('加载 bootstrap 到内存');
      final archiveData = await _loadBootstrapFromAssets();
      BootstrapProfiler.end('加载 bootstrap 到内存');
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

      BootstrapProfiler.end('总初始化时间');
      BootstrapProfiler.printReport();
      return true;
    } catch (e) {
      _status = BootstrapStatus.error;
      _errorMessage = e.toString();
      onProgress?.call(_status, 0.0, 'Error: $_errorMessage');
      debugPrint('Bootstrap initialization failed: $e');

      BootstrapProfiler.end('总初始化时间');
      BootstrapProfiler.printReport();
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
      BootstrapProfiler.start('ZIP 解码 (decodeBytes)');
      final archive = ZipDecoder().decodeBytes(archiveData);
      BootstrapProfiler.end('ZIP 解码 (decodeBytes)');

      final totalFiles = archive.files.length;
      var extractedFiles = 0;
      final symlinks = <String, String>{};
      final executableFiles = <String>[];

      BootstrapProfiler.start('写入文件 ($totalFiles 个)');
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
      BootstrapProfiler.end('写入文件 ($totalFiles 个)');

      // 批量设置可执行权限
      onProgress?.call(
        BootstrapStatus.configuring,
        0.9,
        'Setting permissions for ${executableFiles.length} files...',
      );

      BootstrapProfiler.start('chmod (${executableFiles.length} 个文件)');
      await _setExecutablePermissions(executableFiles);
      BootstrapProfiler.end('chmod (${executableFiles.length} 个文件)');

      // 创建符号链接
      BootstrapProfiler.start('创建符号链接 (${symlinks.length} 个)');
      await _createSymlinks(symlinks);
      BootstrapProfiler.end('创建符号链接 (${symlinks.length} 个)');
    } catch (e) {
      debugPrint('Extraction failed: $e');
      rethrow;
    }
  }

  /// 批量设置可执行权限
  /// 优化：使用 chmod -R 对目录批量设置，而不是逐个文件调用
  static Future<void> _setExecutablePermissions(List<String> files) async {
    // 使用目录级别的批量 chmod，大幅减少进程调用次数
    final binDir = TermuxConstants.binDir;
    final libexecDir = '${TermuxConstants.prefixDir}/libexec';
    final aptMethodsDir = '${TermuxConstants.libDir}/apt/methods';

    final dirsToChmod = [binDir, libexecDir, aptMethodsDir];

    for (final dir in dirsToChmod) {
      if (await Directory(dir).exists()) {
        try {
          // chmod -R 700 对整个目录设置权限
          final result = await Process.run('chmod', ['-R', '700', dir]);
          if (result.exitCode != 0) {
            debugPrint('chmod -R failed for $dir: ${result.stderr}');
          } else {
            debugPrint('chmod -R 700 $dir - success');
          }
        } catch (e) {
          debugPrint('Failed to chmod directory $dir: $e');
        }
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
  static void _parseSymlinks(String content, Map<String, String> symlinks) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('←');
      if (parts.length == 2) {
        final target = parts[0].trim();
        final linkPath = parts[1].trim();
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
        await link.create(target);
        created++;
      } catch (e) {
        debugPrint('Failed to create symlink: $linkPath -> $target: $e');
        failed++;
      }
    }

    debugPrint('Symlinks created: $created, failed: $failed');
  }

  /// 配置环境
  static Future<void> _configureEnvironment() async {
    BootstrapProfiler.start('配置环境 (总计)');

    // 创建环境变量文件
    BootstrapProfiler.start('  writeEnvironmentFile');
    await TermuxEnvironment.writeEnvironmentFile();
    BootstrapProfiler.end('  writeEnvironmentFile');

    // 设置tmp目录权限
    BootstrapProfiler.start('  chmod tmp');
    try {
      await Process.run('chmod', ['1777', TermuxConstants.tmpDir]);
    } catch (e) {
      debugPrint('Failed to set tmp permissions: $e');
    }
    BootstrapProfiler.end('  chmod tmp');

    // 确保关键库文件有正确的链接
    BootstrapProfiler.start('  _ensureCriticalLibraries');
    await _ensureCriticalLibraries();
    BootstrapProfiler.end('  _ensureCriticalLibraries');

    // 配置APT包管理器
    BootstrapProfiler.start('  _configureApt');
    await _configureApt();
    BootstrapProfiler.end('  _configureApt');

    // 创建工具脚本
    BootstrapProfiler.start('  createSetupStorageScript');
    await createSetupStorageScript();
    BootstrapProfiler.end('  createSetupStorageScript');

    // 创建 chsh 替代脚本
    BootstrapProfiler.start('  _createChshScript');
    await _createChshScript();
    BootstrapProfiler.end('  _createChshScript');

    // 创建 termux-reload-settings 替代脚本
    BootstrapProfiler.start('  _createTermuxReloadSettingsScript');
    await _createTermuxReloadSettingsScript();
    BootstrapProfiler.end('  _createTermuxReloadSettingsScript');

    // 创建 bashrc 配置文件
    BootstrapProfiler.start('  _createBashrc');
    await _createBashrc();
    BootstrapProfiler.end('  _createBashrc');

    // 创建 pkg 脚本
    BootstrapProfiler.start('  _createPkgScript');
    await _createPkgScript();
    BootstrapProfiler.end('  _createPkgScript');

    // 创建 bash 包装脚本（必须在其他包装脚本之前）
    BootstrapProfiler.start('  _createBashWrapper');
    await _createBashWrapper();
    BootstrapProfiler.end('  _createBashWrapper');

    // 创建关键二进制包装脚本（apt-key、gpg 等）
    BootstrapProfiler.start('  _createBinaryWrappers');
    await _createBinaryWrappers();
    BootstrapProfiler.end('  _createBinaryWrappers');

    // 确保 sh 符号链接存在（指向 bash-real，必须在 bash 包装之后）
    BootstrapProfiler.start('  _ensureShSymlink');
    await _ensureShSymlink();
    BootstrapProfiler.end('  _ensureShSymlink');

    // 创建 termux-fix-shebang 脚本
    BootstrapProfiler.start('  _createFixShebangScript');
    await _createFixShebangScript();
    BootstrapProfiler.end('  _createFixShebangScript');

    // 创建 APT method 包装脚本（解决 https 方法问题）
    BootstrapProfiler.start('  _createAptMethodWrappers');
    await _createAptMethodWrappers();
    BootstrapProfiler.end('  _createAptMethodWrappers');

    BootstrapProfiler.end('配置环境 (总计)');
  }

  /// 创建 bashrc 配置文件
  static Future<void> _createBashrc() async {
    final bashrcPath = '${TermuxConstants.homeDir}/.bashrc';
    final bashrcFile = File(bashrcPath);

    // 如果已存在则不覆盖用户配置
    if (await bashrcFile.exists()) {
      return;
    }

    const bashrcContent = '''
# ~/.bashrc - Deep Thought Terminal Configuration

# 提示符设置 - 绿色路径
PS1='\\[\\e[0;32m\\]\\w\\[\\e[0m\\] \\\$ '

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
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTCONTROL=ignoredups:erasedups

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

    // 同时创建 .zshrc
    await _createZshrc();
  }

  /// 创建 zshrc 配置文件
  static Future<void> _createZshrc() async {
    final zshrcPath = '${TermuxConstants.homeDir}/.zshrc';
    final zshrcFile = File(zshrcPath);

    // 如果已存在则不覆盖用户配置
    if (await zshrcFile.exists()) {
      return;
    }

    final homeDir = TermuxConstants.homeDir;

    final zshrcContent = '''
# ~/.zshrc - Deep Thought Terminal ZSH Configuration

# ===== 历史记录配置 =====
HISTFILE="$homeDir/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# 历史记录选项
setopt EXTENDED_HISTORY          # 记录时间戳
setopt HIST_EXPIRE_DUPS_FIRST    # 优先删除重复
setopt HIST_IGNORE_DUPS          # 忽略连续重复
setopt HIST_IGNORE_SPACE         # 忽略空格开头的命令
setopt HIST_VERIFY               # 展开历史后先确认
setopt SHARE_HISTORY             # 多终端共享历史
setopt APPEND_HISTORY            # 追加而非覆盖
setopt INC_APPEND_HISTORY        # 立即追加

# ===== 提示符设置 =====
PS1='%F{green}%~%f \$ '

# ===== 颜色支持 =====
export CLICOLOR=1
export CLICOLOR_FORCE=1
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34:*.tar=1;31:*.gz=1;31:*.zip=1;31:*.7z=1;31:*.rar=1;31:*.jpg=1;35:*.jpeg=1;35:*.png=1;35:*.gif=1;35:*.bmp=1;35:*.mp3=1;36:*.mp4=1;36:*.mkv=1;36:*.avi=1;36:*.pdf=1;33:*.doc=1;33:*.txt=0;37'

# ===== 别名 =====
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'

alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias q='exit'

# ===== 补全系统 =====
autoload -Uz compinit
compinit -d "$homeDir/.zcompdump"

# ===== 按键绑定 =====
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward

# ===== Less 颜色 =====
export LESS='-R'
export LESS_TERMCAP_mb=\$'\\e[1;31m'
export LESS_TERMCAP_md=\$'\\e[1;36m'
export LESS_TERMCAP_me=\$'\\e[0m'
export LESS_TERMCAP_so=\$'\\e[1;44;33m'
export LESS_TERMCAP_se=\$'\\e[0m'
export LESS_TERMCAP_us=\$'\\e[1;32m'
export LESS_TERMCAP_ue=\$'\\e[0m'
''';

    try {
      await zshrcFile.writeAsString(zshrcContent);
      debugPrint('Created zshrc at \$zshrcPath');
    } catch (e) {
      debugPrint('Failed to create zshrc: \$e');
    }
  }

  /// 安装 GPG 密钥环
  static Future<void> _installGpgKeyring() async {
    debugPrint('Installing GPG keyring...');

    final shareDir = TermuxConstants.shareDir;
    final etcDir = TermuxConstants.etcDir;
    final keyringSourceDir = Directory('$shareDir/termux-keyring');
    final trustedGpgDir = Directory('$etcDir/apt/trusted.gpg.d');

    try {
      if (!await trustedGpgDir.exists()) {
        await trustedGpgDir.create(recursive: true);
      }

      if (!await keyringSourceDir.exists()) {
        debugPrint('GPG keyring source directory not found: ${keyringSourceDir.path}');
        return;
      }

      int installedKeys = 0;

      await for (final entity in keyringSourceDir.list(followLinks: false)) {
        if (entity is! File) continue;

        final fileName = path.basename(entity.path);
        if (!fileName.endsWith('.gpg')) continue;

        final targetPath = '${trustedGpgDir.path}/$fileName';
        final targetFile = File(targetPath);

        if (await targetFile.exists()) {
          installedKeys++;
          continue;
        }

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

      // 安装 GPG 密钥
      await _installGpgKeyring();

      // 创建 apt.conf
      final aptConfFile = File('$etcDir/apt/apt.conf');
      final caCertFile = '$etcDir/tls/cert.pem';
      final aptConfContent = '''// APT configuration for Deep Thought terminal

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

// SSL/TLS certificate configuration
Acquire::https::CaInfo "$caCertFile";
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";
''';
      await aptConfFile.writeAsString(aptConfContent);
      debugPrint('APT apt.conf configured');

      // 写入sources.list
      final sourcesListFile = File(TermuxConstants.aptSourcesList);
      const sourcesListContent = '''# Termux main repository
deb https://packages-cf.termux.dev/apt/termux-main stable main
''';
      await sourcesListFile.writeAsString(sourcesListContent);
      debugPrint('APT sources.list configured');

      // 创建dpkg目录结构
      final dpkgDir = Directory('$varDir/lib/dpkg');
      final dpkgInfoDir = Directory('$varDir/lib/dpkg/info');
      final dpkgUpdatesDir = Directory('$varDir/lib/dpkg/updates');

      for (final dir in [dpkgDir, dpkgInfoDir, dpkgUpdatesDir]) {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // 清空 dpkg status 文件，避免 bootstrap 构建产物导致的依赖冲突
      // bootstrap 中可能残留一些包记录，这些包的依赖在 bootstrap 中并不存在
      // 例如 dpkg-scanpackages 依赖 dpkg-perl，但 dpkg-perl 不在 bootstrap 中
      final dpkgStatusFile = File('$varDir/lib/dpkg/status');
      await dpkgStatusFile.create(recursive: true);
      await dpkgStatusFile.writeAsString('');

      // 创建dpkg available文件
      final dpkgAvailableFile = File('$varDir/lib/dpkg/available');
      if (!await dpkgAvailableFile.exists()) {
        await dpkgAvailableFile.writeAsString('');
      }

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

      if (await pkgFile.exists()) {
        final content = await pkgFile.readAsString();
        if (content.contains('Deep Thought')) {
          return;
        }
      }

      final libDir = TermuxConstants.libDir;
      final prefixDir = TermuxConstants.prefixDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      final pkgScript = '''#!/system/bin/sh
# pkg - Package manager wrapper for Deep Thought terminal

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

  /// 创建 setup-storage 脚本
  static Future<void> createSetupStorageScript() async {
    final scriptPath = '${TermuxConstants.binDir}/setup-storage';

    try {
      final scriptFile = File(scriptPath);

      if (await scriptFile.exists()) {
        final content = await scriptFile.readAsString();
        if (content.contains('Deep Thought Storage Setup')) {
          return;
        }
      }

      const script = r'''#!/system/bin/sh
# setup-storage - Storage setup for Deep Thought terminal

echo "Deep Thought Storage Setup"
echo ""
echo "This will set up access to external storage."
echo "A permission dialog will be shown if needed."
echo ""

# 发送 OSC 序列触发 Flutter 处理存储权限
printf '\033]7777;setup-storage\007'

echo "Requesting storage permission..."
echo "Please grant access in the system dialog if prompted."
''';

      await scriptFile.writeAsString(script);
      await Process.run('chmod', ['755', scriptPath]);

      // Also create termux-setup-storage
      final termuxScriptPath = '${TermuxConstants.binDir}/termux-setup-storage';
      await File(termuxScriptPath).writeAsString(script);
      await Process.run('chmod', ['755', termuxScriptPath]);

      debugPrint('setup-storage scripts created');
    } catch (e) {
      debugPrint('Failed to create setup-storage script: $e');
    }
  }

  /// 创建 chsh 替代脚本
  static Future<void> _createChshScript() async {
    final chshPath = '${TermuxConstants.binDir}/chsh';
    final homeDir = TermuxConstants.homeDir;
    final binDir = TermuxConstants.binDir;

    try {
      final chshScript = '''#!/system/bin/sh
# chsh - Change login shell for Deep Thought terminal

SHELL_CONFIG="$homeDir/.shell"
BASHRC="$homeDir/.bashrc"

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
}

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

case "\$NEW_SHELL" in
    bash|/*/bash) SHELL_PATH="$binDir/bash" ;;
    zsh|/*/zsh) SHELL_PATH="$binDir/zsh" ;;
    fish|/*/fish) SHELL_PATH="$binDir/fish" ;;
    sh|/*/sh) SHELL_PATH="$binDir/sh" ;;
    /*) SHELL_PATH="\$NEW_SHELL" ;;
    *) SHELL_PATH="$binDir/\$NEW_SHELL" ;;
esac

if [ ! -x "\$SHELL_PATH" ]; then
    echo "Error: Shell '\$SHELL_PATH' not found or not executable"
    exit 1
fi

echo "\$SHELL_PATH" > "\$SHELL_CONFIG"
chmod 600 "\$SHELL_CONFIG"

SHELL_NAME=\$(basename "\$SHELL_PATH")
if [ "\$SHELL_NAME" != "bash" ]; then
    if ! grep -q "^exec.*\$SHELL_NAME" "\$BASHRC" 2>/dev/null; then
        if [ -f "\$BASHRC" ]; then
            sed -i '/^exec.*\\(zsh\\|fish\\)/d' "\$BASHRC" 2>/dev/null
        fi
        echo "" >> "\$BASHRC"
        echo "# Auto-start \$SHELL_NAME (set by chsh)" >> "\$BASHRC"
        echo "exec \$SHELL_PATH" >> "\$BASHRC"
    fi
    echo "Shell changed to \$SHELL_PATH"
else
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

  /// 创建 termux-fix-shebang 脚本
  /// 修复脚本中的 shebang 行，将 /usr/bin/env 等路径替换为 $PREFIX/bin 下的路径
  static Future<void> _createFixShebangScript() async {
    final scriptPath = '${TermuxConstants.binDir}/termux-fix-shebang';
    final prefixBin = TermuxConstants.binDir;

    try {
      final script = '''#!/system/bin/sh
# termux-fix-shebang - Fix shebang lines in scripts for dpterm environment
# Usage: termux-fix-shebang <file> [file2 ...]
#
# Replaces standard shebang paths like #!/usr/bin/env, #!/usr/bin/python, etc.
# with the correct $prefixBin paths.

if [ \$# -eq 0 ]; then
    echo "Usage: termux-fix-shebang <file> [file2 ...]"
    echo ""
    echo "Fix shebang (#!) lines in scripts to use dpterm paths."
    echo "Replaces /usr/bin, /bin paths with $prefixBin"
    exit 1
fi

PREFIX_BIN="$prefixBin"

for file in "\$@"; do
    if [ ! -f "\$file" ]; then
        echo "Warning: \$file not found, skipping"
        continue
    fi

    head_line=\$(head -n1 "\$file")
    case "\$head_line" in
        "#!"*)
            # Replace /usr/bin/env with PREFIX/bin/env
            # Replace /usr/bin/<cmd> with PREFIX/bin/<cmd>
            # Replace /bin/<cmd> with PREFIX/bin/<cmd>
            sed -i "1s|^#!.*/usr/bin/env\\b|#!\$PREFIX_BIN/env|" "\$file"
            sed -i "1s|^#!/usr/bin/|#!\$PREFIX_BIN/|" "\$file"
            sed -i "1s|^#!/bin/|#!\$PREFIX_BIN/|" "\$file"
            echo "Fixed: \$file"
            ;;
        *)
            echo "Skipped (no shebang): \$file"
            ;;
    esac
done
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['755', scriptPath]);
      debugPrint('termux-fix-shebang script created');
    } catch (e) {
      debugPrint('Failed to create termux-fix-shebang script: \$e');
    }
  }

  /// 创建 termux-reload-settings 脚本
  static Future<void> _createTermuxReloadSettingsScript() async {
    final scriptPath = '${TermuxConstants.binDir}/termux-reload-settings';
    final homeDir = TermuxConstants.homeDir;

    try {
      final script = '''#!/system/bin/sh
# termux-reload-settings - Reload terminal settings

TERMUX_CONFIG_DIR="$homeDir/.termux"
SIGNAL_FILE="\$TERMUX_CONFIG_DIR/.reload-settings"
PROPS_FILE="\$TERMUX_CONFIG_DIR/termux.properties"

mkdir -p "\$TERMUX_CONFIG_DIR" 2>/dev/null
touch "\$SIGNAL_FILE"

echo "Settings reload requested."

if [ -f "\$PROPS_FILE" ]; then
    echo "Loading settings from: \$PROPS_FILE"
else
    echo "Note: No termux.properties file found."
    echo "Create \$PROPS_FILE to customize settings."
fi

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
  /// Android 动态链接器可能不正确处理符号链接，需要确保库文件可用
  static Future<void> _ensureCriticalLibraries() async {
    final libDir = TermuxConstants.libDir;

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

    final allEntities = <String, FileSystemEntityType>{};
    await for (final entity in libDirEntity.list(followLinks: false)) {
      final name = path.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      allEntities[name] = type;
    }

    for (final prefix in libPrefixes) {
      await _ensureLibraryLinks(libDir, prefix, allEntities);
    }

    debugPrint('Critical libraries check complete');
  }

  /// 为指定的库前缀创建必要的符号链接或复制文件
  static Future<void> _ensureLibraryLinks(
    String libDir,
    String prefix,
    Map<String, FileSystemEntityType> allEntities,
  ) async {
    final matches = allEntities.keys.where((f) => f.startsWith(prefix)).toList();
    if (matches.isEmpty) return;

    matches.sort((a, b) => b.length.compareTo(a.length));
    String fullVersionFile = matches.first;

    String? actualLibPath;
    final fullVersionPath = '$libDir/$fullVersionFile';

    if (allEntities[fullVersionFile] == FileSystemEntityType.link) {
      try {
        final link = Link(fullVersionPath);
        final target = await link.target();
        if (!target.startsWith('/')) {
          actualLibPath = '$libDir/$target';
        } else {
          actualLibPath = target;
        }
        if (!await File(actualLibPath).exists()) {
          actualLibPath = null;
        }
      } catch (e) {
        debugPrint('Failed to resolve symlink $fullVersionPath: $e');
      }
    } else if (allEntities[fullVersionFile] == FileSystemEntityType.file) {
      actualLibPath = fullVersionPath;
    }

    if (actualLibPath == null) return;

    final versionsToCreate = <String>{};
    versionsToCreate.add(prefix);

    final versionPart = fullVersionFile.substring(prefix.length);
    if (versionPart.startsWith('.')) {
      final versionNumbers = versionPart.substring(1).split('.');
      String currentVersion = prefix;

      for (int i = 0; i < versionNumbers.length; i++) {
        currentVersion = '$currentVersion.${versionNumbers[i]}';
        versionsToCreate.add(currentVersion);
      }
    }

    for (final versionName in versionsToCreate) {
      final versionPath = '$libDir/$versionName';

      final exists = await File(versionPath).exists();
      final isLink = await FileSystemEntity.isLink(versionPath);

      if (exists && !isLink) continue;

      try {
        if (isLink) {
          await Link(versionPath).delete();
        }
        await File(actualLibPath).copy(versionPath);
      } catch (e) {
        debugPrint('Failed to copy library $versionName: $e');
      }
    }
  }

  /// 创建 bash 包装脚本
  /// bash 二进制需要正确的环境变量才能运行
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
      final homeDir = TermuxConstants.homeDir;

      final wrapperScript = '''#!/system/bin/sh
# Bash wrapper script
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export HOME="$homeDir"
exec "$bashRealPath" --rcfile "$homeDir/.bashrc" "\$@"
''';

      await bashFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', bashPath]);
      debugPrint('Created bash wrapper script');
    } catch (e) {
      debugPrint('Failed to create bash wrapper: $e');
    }
  }

  /// 确保 sh 符号链接存在
  /// apt-key 等脚本使用 #!/.../bin/sh 作为解释器
  /// 注意: sh 必须指向 bash-real 而不是 bash，因为 bash 现在是包装脚本
  static Future<void> _ensureShSymlink() async {
    final binDir = TermuxConstants.binDir;
    final shPath = '$binDir/sh';
    final bashRealPath = '$binDir/bash-real';

    try {
      // 检查 bash-real 是否存在
      final bashRealExists = await File(bashRealPath).exists();
      // 如果 bash-real 不存在，回退到 bash
      final targetName = bashRealExists ? 'bash-real' : 'bash';

      final shType = await FileSystemEntity.type(shPath, followLinks: false);

      if (shType == FileSystemEntityType.notFound) {
        // sh 不存在，创建符号链接
        await Link(shPath).create(targetName);
        await Process.run('chmod', ['755', shPath]);
        debugPrint('Created sh symlink -> $targetName');
      } else if (shType == FileSystemEntityType.link) {
        // 检查符号链接是否指向正确的目标
        final link = Link(shPath);
        try {
          final currentTarget = await link.target();
          // 如果 bash-real 存在但 sh 指向 bash，需要更新
          if (bashRealExists && currentTarget == 'bash') {
            await link.delete();
            await Link(shPath).create('bash-real');
            debugPrint('Updated sh symlink: bash -> bash-real');
          }
        } catch (e) {
          // 无法读取目标，重新创建
          await link.delete();
          await Link(shPath).create(targetName);
          debugPrint('Recreated sh symlink -> $targetName');
        }
      } else if (shType == FileSystemEntityType.file) {
        // sh 是一个文件而不是符号链接
        // 删除它并创建符号链接
        await File(shPath).delete();
        await Link(shPath).create(targetName);
        debugPrint('Replaced sh file with symlink -> $targetName');
      }
    } catch (e) {
      debugPrint('Failed to ensure sh symlink: $e');
    }
  }

  /// 为关键二进制创建包装脚本
  /// 解决 apt-key、gpg 等无法执行的问题
  static Future<void> _createBinaryWrappers() async {
    // 需要包装的二进制列表
    // 注意: bash 不在此列表中，由 _createBashWrapper() 专门处理
    final binariesToWrap = [
      'apt-key',
      'gpg',
      'gpgv',
      'gpg-agent',
      // dpkg 相关命令需要正确的 PATH 来找到 rm、cp 等
      // dpkg 由 _createDpkgWrapper() 专门处理（需要补丁 .deb）
      'dpkg',
      'dpkg-deb',
      'dpkg-query',
      'dpkg-trigger',
      // apt 相关命令
      'apt',
      'apt-get',
      'apt-cache',
      'apt-config',
    ];

    for (final binaryName in binariesToWrap) {
      await _createBinaryWrapper(binaryName);
    }
  }

  /// 为单个二进制创建包装脚本
  static Future<void> _createBinaryWrapper(String binaryName) async {
    // dpkg 需要特殊处理 - 补丁从官方源下载的 .deb 文件
    if (binaryName == 'dpkg') {
      await _createDpkgWrapper();
      return;
    }

    final binPath = '${TermuxConstants.binDir}/$binaryName';
    final realPath = '${TermuxConstants.binDir}/$binaryName.real';

    try {
      final binFile = File(binPath);
      final realFile = File(realPath);

      // 如果 .real 文件已存在，检查包装脚本是否最新
      if (await realFile.exists()) {
        if (await binFile.exists()) {
          try {
            final content = await binFile.readAsString();
            // 检查版本标记，确保使用最新版本的包装脚本
            if (content.contains('wrapper-v2')) {
              return; // 已经是最新的包装脚本
            }
          } catch (_) {}
        }
        // 需要重新创建包装脚本
      } else {
        // 检查原始二进制是否存在
        if (!await binFile.exists()) {
          return;
        }

        // 检查是否是 ELF 二进制
        final bytes = await binFile.openRead(0, 4).first;
        if (bytes.length < 4 ||
            bytes[0] != 0x7f || bytes[1] != 0x45 ||
            bytes[2] != 0x4c || bytes[3] != 0x46) {
          // 不是 ELF，可能已经是脚本
          // 检查是否是需要修复的脚本
          try {
            final content = await binFile.readAsString();
            if (content.contains('/data/data/com.termux/')) {
              // 需要修复路径
              final newContent = content
                  .replaceAll('/data/data/com.termux/', '/data/data/com.dpterm/');
              await binFile.writeAsString(newContent);
              debugPrint('Fixed paths in script: $binaryName');
            }
          } catch (_) {}
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
      final homeDir = TermuxConstants.homeDir;
      final prefixDir = TermuxConstants.prefixDir;
      final etcDir = TermuxConstants.etcDir;

      final wrapperScript = '''#!/system/bin/sh
# Wrapper script for $binaryName
# Version: wrapper-v2
export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export PREFIX="$prefixDir"
export TMPDIR="$tmpDir"
export HOME="$homeDir"
export GNUPGHOME="$homeDir/.gnupg"
export APT_CONFIG="$etcDir/apt/apt.conf"
export SSL_CERT_FILE="$etcDir/tls/cert.pem"
exec "$realPath" "\$@"
''';

      await binFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', binPath]);

      debugPrint('Created wrapper for $binaryName');
    } catch (e) {
      debugPrint('Failed to create wrapper for $binaryName: $e');
    }
  }

  /// 创建 dpkg 特殊包装脚本
  /// 从官方 Termux 源下载的 .deb 包含 com.termux 路径
  /// 需要在安装前补丁为 com.dpterm
  static Future<void> _createDpkgWrapper() async {
    final dpkgPath = '${TermuxConstants.binDir}/dpkg';
    final dpkgRealPath = '${TermuxConstants.binDir}/dpkg.real';

    try {
      final dpkgFile = File(dpkgPath);
      final dpkgRealFile = File(dpkgRealPath);

      // 检查是否需要更新
      if (await dpkgRealFile.exists()) {
        if (await dpkgFile.exists()) {
          try {
            final content = await dpkgFile.readAsString();
            if (content.contains('dpkg-patch-v1')) {
              return; // 已经是最新版本
            }
          } catch (_) {}
        }
      } else {
        if (!await dpkgFile.exists()) return;

        // 检查是否是 ELF 二进制
        final bytes = await dpkgFile.openRead(0, 4).first;
        if (bytes.length < 4 ||
            bytes[0] != 0x7f || bytes[1] != 0x45 ||
            bytes[2] != 0x4c || bytes[3] != 0x46) {
          return;
        }

        // 重命名原始 dpkg 为 dpkg.real
        await dpkgFile.rename(dpkgRealPath);
        await Process.run('chmod', ['755', dpkgRealPath]);
      }

      // 创建 dpkg 包装脚本
      final libDir = TermuxConstants.libDir;
      final binDir = TermuxConstants.binDir;
      final tmpDir = TermuxConstants.tmpDir;
      final etcDir = TermuxConstants.etcDir;

      final wrapperScript = '''#!/system/bin/sh
# dpkg wrapper - patches .deb files from official Termux repo
# Replaces com.termux -> com.dpterm before installation
# Version: dpkg-patch-v1

export PATH="$binDir:/system/bin:/system/xbin"
export LD_LIBRARY_PATH="$libDir"
export TMPDIR="$tmpDir"
export APT_CONFIG="$etcDir/apt/apt.conf"

DPKG_REAL="$dpkgRealPath"

patch_deb() {
    local debfile="\$1"
    [ ! -f "\$debfile" ] && return 1

    local tmpdir="\$TMPDIR/dpkg-patch-\$\$"
    mkdir -p "\$tmpdir/extract"

    "\$DPKG_REAL" --extract "\$debfile" "\$tmpdir/extract" 2>/dev/null
    "\$DPKG_REAL" --control "\$debfile" "\$tmpdir/extract/DEBIAN" 2>/dev/null
    [ \$? -ne 0 ] && { rm -rf "\$tmpdir"; return 1; }

    local modified=0

    # 重命名 com.termux 目录
    if [ -d "\$tmpdir/extract/data/data/com.termux" ]; then
        mv "\$tmpdir/extract/data/data/com.termux" "\$tmpdir/extract/data/data/com.dpterm"
        modified=1
    fi

    # 补丁文件中的 com.termux 路径
    for f in \$(find "\$tmpdir/extract" -type f 2>/dev/null); do
        if grep -q "com\\.termux" "\$f" 2>/dev/null; then
            LC_ALL=C sed -i 's|com\\.termux|com.dpterm|g' "\$f" 2>/dev/null
            modified=1
        fi
    done

    # 重新打包
    if [ \$modified -eq 1 ]; then
        [ -d "\$tmpdir/extract/DEBIAN" ] && chmod 755 "\$tmpdir/extract/DEBIAN"/* 2>/dev/null
        "\$DPKG_REAL" --build "\$tmpdir/extract" "\$tmpdir/patched.deb" 2>/dev/null
        [ -f "\$tmpdir/patched.deb" ] && cp "\$tmpdir/patched.deb" "\$debfile"
    fi

    rm -rf "\$tmpdir"
}

# 检查是否是安装操作
SHOULD_PATCH=0
for arg in "\$@"; do
    case "\$arg" in -i|--install|-R|--recursive|--unpack) SHOULD_PATCH=1 ;; esac
done

# 补丁 .deb 文件
if [ \$SHOULD_PATCH -eq 1 ]; then
    for arg in "\$@"; do
        case "\$arg" in
            *.deb) [ -f "\$arg" ] && patch_deb "\$arg" ;;
            /*) [ -d "\$arg" ] && for d in "\$arg"/*.deb; do [ -f "\$d" ] && patch_deb "\$d"; done ;;
        esac
    done
fi

exec "\$DPKG_REAL" "\$@"
''';

      await dpkgFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', dpkgPath]);
      debugPrint('Created dpkg wrapper for .deb patching');
    } catch (e) {
      debugPrint('Failed to create dpkg wrapper: $e');
    }
  }

  /// 为 APT methods 创建包装脚本
  /// 解决 https 方法找不到的问题
  static Future<void> _createAptMethodWrappers() async {
    final methodsDir = Directory('${TermuxConstants.libDir}/apt/methods');

    if (!await methodsDir.exists()) {
      debugPrint('APT methods directory not found');
      return;
    }

    debugPrint('Processing APT methods in ${methodsDir.path}');

    // 需要包装的方法（有网络请求或需要 SSL 证书）
    final methodsToWrap = ['http', 'https', 'ftp', 'rsh', 'ssh'];

    for (final methodName in methodsToWrap) {
      await _createAptMethodWrapper(methodName);
    }

    // 确保 https -> http.real 的别名存在
    await _ensureMethodAlias('https', 'http');
    await _ensureMethodAlias('ssh', 'rsh');
  }

  /// 为单个 APT method 创建包装脚本
  static Future<void> _createAptMethodWrapper(String methodName) async {
    final methodsDir = '${TermuxConstants.libDir}/apt/methods';
    final methodPath = '$methodsDir/$methodName';
    final realPath = '$methodsDir/$methodName.real';

    try {
      final realFile = File(realPath);

      // 如果 .real 文件已存在，检查包装脚本是否是最新的
      if (await realFile.exists()) {
        final methodFile = File(methodPath);
        if (await methodFile.exists()) {
          try {
            final content = await methodFile.readAsString();
            if (content.contains('#!/system/bin/sh') &&
                content.contains('SSL_CERT_FILE')) {
              return; // 已经是包装脚本且是最新的
            }
          } catch (_) {}
        }
      }

      // 检查文件或符号链接是否存在
      final entityType = await FileSystemEntity.type(methodPath, followLinks: false);
      if (entityType == FileSystemEntityType.notFound) {
        return;
      }

      // 如果是符号链接，跳过（由 _ensureMethodAlias 处理）
      if (entityType == FileSystemEntityType.link) {
        return;
      }

      // 检查是否是 ELF 二进制
      final file = File(methodPath);
      final bytes = await file.openRead(0, 4).first;
      if (bytes.length < 4 ||
          bytes[0] != 0x7f || bytes[1] != 0x45 ||
          bytes[2] != 0x4c || bytes[3] != 0x46) {
        return; // 不是 ELF
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
# APT method wrapper for Deep Thought terminal
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

  /// 确保方法别名存在（如 https -> http.real）
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
      final entityType = await FileSystemEntity.type(aliasPath, followLinks: false);

      if (entityType == FileSystemEntityType.file) {
        try {
          final content = await aliasFile.readAsString();
          if (content.contains('#!/system/bin/sh') &&
              content.contains(targetRealPath) &&
              content.contains('SSL_CERT_FILE')) {
            return; // 已经是正确的包装脚本
          }
        } catch (_) {}
      }

      // 删除现有文件或符号链接
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
exec "$targetRealPath" "\$@"
''';

      await aliasFile.writeAsString(wrapperScript);
      await Process.run('chmod', ['755', aliasPath]);

      debugPrint('Created/fixed apt method alias: $aliasName -> $targetRealPath');
    } catch (e) {
      debugPrint('Failed to ensure method alias $aliasName: $e');
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
    final caCertFile = '${TermuxConstants.etcDir}/tls/cert.pem';
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
      'LD_LIBRARY_PATH': TermuxConstants.libDir,
      'ANDROID_ROOT': '/system',
      'ANDROID_DATA': '/data',
      'APT_CONFIG': aptConfFile,
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
