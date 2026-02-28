import 'dart:io' show File, Platform;

/// 应用常量定义
/// 参考 termux-app: TermuxConstants.java, TermuxPreferenceConstants.java

class AppConstants {
  static const String appName = 'Deep Thought';
  static const String packageName = 'com.dpterm';
  static const String version = '0.1.1+2';
}

/// 文件系统路径常量
/// Android: 使用 Termux 风格的目录结构
/// Linux/Desktop: 使用系统原生路径
class TermuxConstants {
  /// 是否为桌面平台（Linux/macOS/Windows）
  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;

  // ==================== 基础路径 ====================

  /// 应用数据目录（仅 Android 使用）
  static String get filesDir {
    if (Platform.isAndroid) {
      return '/data/data/${AppConstants.packageName}/files';
    }
    // 桌面平台不需要特殊的 filesDir
    return Platform.environment['HOME'] ?? '/tmp';
  }

  /// 用户主目录
  static String get homeDir {
    if (Platform.isAndroid) {
      return '$filesDir/home';
    }
    // 桌面平台：直接使用系统 HOME
    return Platform.environment['HOME'] ?? '/tmp';
  }

  /// PREFIX 目录（仅 Android/Termux 使用）
  static String get prefixDir {
    if (Platform.isAndroid) {
      return '$filesDir/usr';
    }
    return '/usr';
  }

  /// 临时安装目录（仅 Android 使用）
  static String get stagingPrefixDir => '$filesDir/usr-staging';

  // ==================== 系统目录 ====================

  /// 可执行文件目录
  static String get binDir {
    if (Platform.isAndroid) {
      return '$prefixDir/bin';
    }
    return '/usr/bin';
  }

  /// 库文件目录
  static String get libDir {
    if (Platform.isAndroid) {
      return '$prefixDir/lib';
    }
    return '/usr/lib';
  }

  static String get libexecDir {
    if (Platform.isAndroid) {
      return '$prefixDir/libexec';
    }
    return '/usr/libexec';
  }

  /// 配置文件目录
  static String get etcDir {
    if (Platform.isAndroid) {
      return '$prefixDir/etc';
    }
    return '/etc';
  }

  static String get shareDir {
    if (Platform.isAndroid) {
      return '$prefixDir/share';
    }
    return '/usr/share';
  }

  /// 临时文件目录
  static String get tmpDir {
    if (Platform.isAndroid) {
      return '$prefixDir/tmp';
    }
    return '/tmp';
  }

  static String get varDir {
    if (Platform.isAndroid) {
      return '$prefixDir/var';
    }
    return '/var';
  }

  static String get includeDir {
    if (Platform.isAndroid) {
      return '$prefixDir/include';
    }
    return '/usr/include';
  }

  // ==================== 配置目录 ====================

  /// Termux 配置目录（~/.termux）
  static String get termuxConfigDir => '$homeDir/.termux';

  /// 应用配置目录
  static String get configDir {
    if (Platform.isAndroid) {
      return '$homeDir/.config/termux';
    }
    return '$homeDir/.config/dpterm';
  }

  static String get storageDir => '$homeDir/storage';

  // ==================== Shell 路径 ====================

  /// Bash 路径
  static String get bashPath {
    if (Platform.isAndroid) {
      return '$binDir/bash';
    }
    // 桌面平台：尝试常见路径
    if (File('/bin/bash').existsSync()) return '/bin/bash';
    if (File('/usr/bin/bash').existsSync()) return '/usr/bin/bash';
    return '/bin/sh';
  }

  /// sh 路径
  static String get shPath {
    if (Platform.isAndroid) {
      return '$binDir/sh';
    }
    if (File('/bin/sh').existsSync()) return '/bin/sh';
    return '/usr/bin/sh';
  }

  /// login 路径
  static String get loginPath {
    if (Platform.isAndroid) {
      return '$binDir/login';
    }
    return '/usr/bin/login';
  }

  static String get envFile => '$termuxConfigDir/termux.env';
  static String get propertiesFile => '$configDir/termux.properties';
  static String get symlinksFile => 'SYMLINKS.txt';

  // Bootstrap 相关 - 使用Termux官方bootstrap包
  // https://github.com/termux/termux-packages/releases
  static const String bootstrapArchive = 'bootstrap.zip';
  static const String bootstrapVersion =
      'bootstrap-2026.01.11-r1+apt.android-7';
  static const String bootstrapBaseUrl =
      'https://github.com/termux/termux-packages/releases/download';

  // ARM64 (aarch64) - 大多数现代Android设备
  static String get bootstrapUrlAarch64 =>
      '$bootstrapBaseUrl/${Uri.encodeComponent(bootstrapVersion)}/bootstrap-aarch64.zip';

  // x86_64 - 模拟器和部分平板
  static String get bootstrapUrlX86_64 =>
      '$bootstrapBaseUrl/${Uri.encodeComponent(bootstrapVersion)}/bootstrap-x86_64.zip';

  // ARM (armeabi-v7a) - 旧设备
  static String get bootstrapUrlArm =>
      '$bootstrapBaseUrl/${Uri.encodeComponent(bootstrapVersion)}/bootstrap-arm.zip';

  // x86 (i686) - 旧模拟器
  static String get bootstrapUrlI686 =>
      '$bootstrapBaseUrl/${Uri.encodeComponent(bootstrapVersion)}/bootstrap-i686.zip';

  // APT 配置
  static String get aptSourcesList => '$etcDir/apt/sources.list';
  static String get aptSourcesDir => '$etcDir/apt/sources.list.d';

  // 默认 Shell
  static String get defaultShell => bashPath;

  /// 备用 Shell（系统级）
  static String get fallbackShell {
    if (Platform.isAndroid) {
      return '/system/bin/sh';
    }
    return '/bin/sh';
  }
}

/// 默认设置值
class DefaultSettings {
  static const double fontSize = 14.0;
  static const double minFontSize = 8.0;
  static const double maxFontSize = 32.0;
  static const String fontFamily = 'JetBrains Mono Nerd'; // 默认使用内置 Nerd Font
  static const String colorTheme = 'default';
  static const String cursorStyle = 'block';
  static const bool cursorBlink = true;
  static const bool keepScreenOn = false;
  static const bool showExtraKeys = true;
  static const bool vibrationEnabled = true;
  static const int terminalMargin = 0;
  static const bool bellEnabled = true;
  static const bool pinchZoomEnabled = true;
  static const String volumeUpAction = 'ctrl';
  static const String volumeDownAction = 'alt';
}

/// 可用字体列表
class AvailableFonts {
  /// 默认 Nerd Font 名称（用于显示）
  static const String nerdFont = 'JetBrains Mono Nerd';

  /// 默认 Nerd Font 的实际字体族名称
  static const String nerdFontFamily = 'JetBrainsMonoNerdFontMono';

  /// 自定义字体族名称（用于 ~/.termux/font.ttf）
  static const String customFontFamily = 'CustomTerminalFont';

  /// 内置 Nerd Fonts MONO 变体（支持 Powerline/p10k 图标）
  /// 使用 MONO 变体确保所有字符（包括图标）宽度一致，避免重叠
  /// key: 显示名称, value: Flutter 字体族名称
  static const Map<String, String> builtInNerdFonts = {
    'JetBrains Mono Nerd': 'JetBrainsMonoNerdFontMono',
    'Fira Code Nerd': 'FiraCodeNerdFontMono',
    'Hack Nerd': 'HackNerdFontMono',
    'Source Code Pro Nerd': 'SourceCodeProNerdFontMono',
    'Ubuntu Mono Nerd': 'UbuntuMonoNerdFontMono',
    'Cascadia Code Nerd': 'CascadiaCodeNerdFontMono',
  };

  /// Google Fonts（不支持 Powerline 图标）
  static const List<String> googleFonts = [
    'Roboto Mono',
    'Fira Code',
    'Ubuntu Mono',
    'Courier Prime',
    'Inconsolata',
    'Source Code Pro',
    'JetBrains Mono',
  ];

  /// 所有可用字体（Nerd Fonts 在前）
  static List<String> get fonts => [
        ...builtInNerdFonts.keys,
        ...googleFonts,
      ];

  /// 判断是否为内置 Nerd Font
  static bool isBuiltInNerdFont(String fontFamily) {
    return builtInNerdFonts.containsKey(fontFamily) ||
        builtInNerdFonts.containsValue(fontFamily);
  }

  /// 获取内置字体的 Flutter 字体族名称
  static String? getBuiltInFontFamily(String displayName) {
    return builtInNerdFonts[displayName];
  }

  /// 获取字体显示名称
  static String getDisplayName(String fontFamily,
      {bool hasCustomFont = false}) {
    // 检查是否为内置 Nerd Font
    if (builtInNerdFonts.containsKey(fontFamily)) {
      return '$fontFamily (Built-in)';
    }
    // 检查是否为 Nerd Font 的字体族名称
    for (final entry in builtInNerdFonts.entries) {
      if (entry.value == fontFamily) {
        return '${entry.key} (Built-in)';
      }
    }
    if (fontFamily == customFontFamily) {
      return 'Custom Font (~/.termux/font.ttf)';
    }
    return fontFamily;
  }
}

/// 光标样式
class CursorStyles {
  static const String block = 'block';
  static const String underline = 'underline';
  static const String bar = 'bar';

  static const List<String> all = [block, underline, bar];
}

/// 音量键动作预设
class VolumeKeyActions {
  /// 预设动作映射
  /// key: 动作标识符, value: (显示名称, 发送的字符序列, 是否为修饰键)
  static const Map<String, (String, String, bool)> presets = {
    'ctrl': ('Ctrl', '', true), // Ctrl 修饰键
    'alt': ('Alt', '\x1b', true), // Alt 修饰键 (发送 Escape)
    'esc': ('Esc', '\x1b', false), // Escape 键
    'tab': ('Tab', '\t', false), // Tab 键
    'up': ('↑', '\x1b[A', false), // 方向上
    'down': ('↓', '\x1b[B', false), // 方向下
    'left': ('←', '\x1b[D', false), // 方向左
    'right': ('→', '\x1b[C', false), // 方向右
    'pgup': ('PgUp', '\x1b[5~', false), // Page Up
    'pgdn': ('PgDn', '\x1b[6~', false), // Page Down
    'home': ('Home', '\x1b[H', false), // Home
    'end': ('End', '\x1b[F', false), // End
    'none': ('禁用', '', false), // 禁用
  };

  /// 获取动作的显示名称
  static String getDisplayName(String action) {
    if (action.startsWith('custom:')) {
      final customValue = action.substring(7);
      return '自定义: $customValue';
    }
    return presets[action]?.$1 ?? action;
  }

  /// 获取动作要发送的字符序列
  static String getSequence(String action) {
    if (action.startsWith('custom:')) {
      return _parseCustomSequence(action.substring(7));
    }
    return presets[action]?.$2 ?? '';
  }

  /// 判断是否为修饰键模式
  static bool isModifier(String action) {
    if (action.startsWith('custom:')) return false;
    return presets[action]?.$3 ?? false;
  }

  /// 解析自定义序列（支持 \x1b, \t, \n 等转义）
  static String _parseCustomSequence(String input) {
    return input
        .replaceAll(r'\x1b', '\x1b')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\\', '\\');
  }

  /// 创建自定义动作
  static String createCustomAction(String sequence) {
    return 'custom:$sequence';
  }

  /// 判断是否为自定义动作
  static bool isCustom(String action) {
    return action.startsWith('custom:');
  }

  /// 获取自定义动作的原始值
  static String? getCustomValue(String action) {
    if (action.startsWith('custom:')) {
      return action.substring(7);
    }
    return null;
  }
}

/// 可用的 Shell 列表
class AvailableShells {
  /// Shell 配置: key = 显示名称, value = shell 名称
  static const Map<String, String> shells = {
    'Bash': 'bash',
    'Zsh': 'zsh',
    'Fish': 'fish',
    'Sh': 'sh',
  };

  /// 默认 Shell
  static const String defaultShell = 'bash';

  /// 获取 Shell 的完整路径
  static String getFullPath(String shellName) {
    if (TermuxConstants.isDesktop) {
      // 桌面平台：查找系统 shell
      final paths = ['/bin/$shellName', '/usr/bin/$shellName'];
      for (final path in paths) {
        if (File(path).existsSync()) {
          return path;
        }
      }
      // 未找到，返回默认路径
      return '/usr/bin/$shellName';
    }
    // Android: 使用 Termux bin 目录
    return '${TermuxConstants.binDir}/$shellName';
  }

  /// 获取显示名称
  static String getDisplayName(String shellName) {
    for (final entry in shells.entries) {
      if (entry.value == shellName) {
        return entry.key;
      }
    }
    return shellName;
  }
}
