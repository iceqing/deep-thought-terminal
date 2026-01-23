/// 应用常量定义
/// 参考 termux-app: TermuxConstants.java, TermuxPreferenceConstants.java

class AppConstants {
  static const String appName = 'Deep Thought';
  static const String packageName = 'com.dpterm';
  static const String version = '1.0.0';
}

/// Termux 文件系统路径常量
/// 参考 termux-app: TermuxConstants.java
class TermuxConstants {
  // 基础路径 - Android 应用数据目录
  static String get filesDir => '/data/data/${AppConstants.packageName}/files';

  // 核心目录
  static String get prefixDir => '$filesDir/usr';           // PREFIX
  static String get homeDir => '$filesDir/home';            // HOME
  static String get stagingPrefixDir => '$filesDir/usr-staging';  // 临时安装目录

  // PREFIX 子目录
  static String get binDir => '$prefixDir/bin';
  static String get libDir => '$prefixDir/lib';
  static String get libexecDir => '$prefixDir/libexec';
  static String get etcDir => '$prefixDir/etc';
  static String get shareDir => '$prefixDir/share';
  static String get tmpDir => '$prefixDir/tmp';
  static String get varDir => '$prefixDir/var';
  static String get includeDir => '$prefixDir/include';

  // HOME 子目录
  static String get termuxConfigDir => '$homeDir/.termux';
  static String get configDir => '$homeDir/.config/termux';
  static String get storageDir => '$homeDir/storage';

  // 重要文件
  static String get bashPath => '$binDir/bash';
  static String get shPath => '$binDir/sh';
  static String get loginPath => '$binDir/login';
  static String get envFile => '$termuxConfigDir/termux.env';
  static String get propertiesFile => '$configDir/termux.properties';
  static String get symlinksFile => 'SYMLINKS.txt';

  // Bootstrap 相关 - 使用Termux官方bootstrap包
  // https://github.com/termux/termux-packages/releases
  static const String bootstrapArchive = 'bootstrap.zip';
  static const String bootstrapVersion = 'bootstrap-2026.01.11-r1+apt.android-7';
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
  static const String fallbackShell = '/system/bin/sh';
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
  static const bool volumeKeysEnabled = true;
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
  static String getDisplayName(String fontFamily, {bool hasCustomFont = false}) {
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
