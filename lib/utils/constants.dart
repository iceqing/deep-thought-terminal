/// 应用常量定义
/// 参考 termux-app: TermuxPreferenceConstants.java

class AppConstants {
  static const String appName = 'Deep Thought';
  static const String version = '1.0.0';
}

/// 默认设置值
class DefaultSettings {
  static const double fontSize = 14.0;
  static const double minFontSize = 8.0;
  static const double maxFontSize = 32.0;
  static const String fontFamily = 'Roboto Mono';
  static const String colorTheme = 'default';
  static const String cursorStyle = 'block';
  static const bool cursorBlink = true;
  static const bool keepScreenOn = false;
  static const bool showExtraKeys = true;
  static const bool vibrationEnabled = true;
  static const int terminalMargin = 0;
  static const bool bellEnabled = true;
}

/// 可用字体列表
class AvailableFonts {
  static const List<String> fonts = [
    'Roboto Mono',
    'Fira Code',
    'Ubuntu Mono',
    'Courier Prime',
    'Inconsolata',
    'Source Code Pro',
    'JetBrains Mono',
  ];
}

/// 光标样式
class CursorStyles {
  static const String block = 'block';
  static const String underline = 'underline';
  static const String bar = 'bar';

  static const List<String> all = [block, underline, bar];
}
