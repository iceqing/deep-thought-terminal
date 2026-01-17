import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// 终端颜色主题
/// 参考 termux-app: TerminalColorScheme.java

class AppTerminalThemes {
  static const Map<String, TerminalTheme> themes = {
    'default': _defaultTheme,
    'dracula': _draculaTheme,
    'monokai': _monokaiTheme,
    'solarized_dark': _solarizedDarkTheme,
    'solarized_light': _solarizedLightTheme,
    'nord': _nordTheme,
    'gruvbox': _gruvboxTheme,
    'one_dark': _oneDarkTheme,
  };

  static List<String> get themeNames => themes.keys.toList();

  static TerminalTheme getTheme(String name) {
    return themes[name] ?? _defaultTheme;
  }

  // Default Theme (类似 Termux 默认主题)
  static const _defaultTheme = TerminalTheme(
    cursor: Color(0xFFAAAAAA),
    selection: Color(0x80FFFFFF),
    foreground: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFFFF6600),
    searchHitForeground: Color(0xFF000000),
  );

  // Dracula Theme
  static const _draculaTheme = TerminalTheme(
    cursor: Color(0xFFF8F8F2),
    selection: Color(0x4044475A),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    black: Color(0xFF21222C),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6272A4),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFFFF6600),
    searchHitForeground: Color(0xFF000000),
  );

  // Monokai Theme
  static const _monokaiTheme = TerminalTheme(
    cursor: Color(0xFFF8F8F0),
    selection: Color(0x4049483E),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF272822),
    black: Color(0xFF272822),
    red: Color(0xFFF92672),
    green: Color(0xFFA6E22E),
    yellow: Color(0xFFF4BF75),
    blue: Color(0xFF66D9EF),
    magenta: Color(0xFFAE81FF),
    cyan: Color(0xFFA1EFE4),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF75715E),
    brightRed: Color(0xFFF92672),
    brightGreen: Color(0xFFA6E22E),
    brightYellow: Color(0xFFF4BF75),
    brightBlue: Color(0xFF66D9EF),
    brightMagenta: Color(0xFFAE81FF),
    brightCyan: Color(0xFFA1EFE4),
    brightWhite: Color(0xFFF9F8F5),
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFFFF6600),
    searchHitForeground: Color(0xFF000000),
  );

  // Solarized Dark Theme
  static const _solarizedDarkTheme = TerminalTheme(
    cursor: Color(0xFF839496),
    selection: Color(0x40073642),
    foreground: Color(0xFF839496),
    background: Color(0xFF002B36),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFFFF6600),
    searchHitForeground: Color(0xFF000000),
  );

  // Solarized Light Theme
  static const _solarizedLightTheme = TerminalTheme(
    cursor: Color(0xFF657B83),
    selection: Color(0x40EEE8D5),
    foreground: Color(0xFF657B83),
    background: Color(0xFFFDF6E3),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFF268BD2),
    searchHitBackgroundCurrent: Color(0xFFCB4B16),
    searchHitForeground: Color(0xFFFDF6E3),
  );

  // Nord Theme
  static const _nordTheme = TerminalTheme(
    cursor: Color(0xFFD8DEE9),
    selection: Color(0x404C566A),
    foreground: Color(0xFFD8DEE9),
    background: Color(0xFF2E3440),
    black: Color(0xFF3B4252),
    red: Color(0xFFBF616A),
    green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD),
    cyan: Color(0xFF88C0D0),
    white: Color(0xFFE5E9F0),
    brightBlack: Color(0xFF4C566A),
    brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C),
    brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1),
    brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB),
    brightWhite: Color(0xFFECEFF4),
    searchHitBackground: Color(0xFFEBCB8B),
    searchHitBackgroundCurrent: Color(0xFFD08770),
    searchHitForeground: Color(0xFF2E3440),
  );

  // Gruvbox Theme
  static const _gruvboxTheme = TerminalTheme(
    cursor: Color(0xFFEBDBB2),
    selection: Color(0x40504945),
    foreground: Color(0xFFEBDBB2),
    background: Color(0xFF282828),
    black: Color(0xFF282828),
    red: Color(0xFFCC241D),
    green: Color(0xFF98971A),
    yellow: Color(0xFFD79921),
    blue: Color(0xFF458588),
    magenta: Color(0xFFB16286),
    cyan: Color(0xFF689D6A),
    white: Color(0xFFA89984),
    brightBlack: Color(0xFF928374),
    brightRed: Color(0xFFFB4934),
    brightGreen: Color(0xFFB8BB26),
    brightYellow: Color(0xFFFABD2F),
    brightBlue: Color(0xFF83A598),
    brightMagenta: Color(0xFFD3869B),
    brightCyan: Color(0xFF8EC07C),
    brightWhite: Color(0xFFEBDBB2),
    searchHitBackground: Color(0xFFFABD2F),
    searchHitBackgroundCurrent: Color(0xFFFE8019),
    searchHitForeground: Color(0xFF282828),
  );

  // One Dark Theme
  static const _oneDarkTheme = TerminalTheme(
    cursor: Color(0xFF528BFF),
    selection: Color(0x403E4451),
    foreground: Color(0xFFABB2BF),
    background: Color(0xFF282C34),
    black: Color(0xFF282C34),
    red: Color(0xFFE06C75),
    green: Color(0xFF98C379),
    yellow: Color(0xFFE5C07B),
    blue: Color(0xFF61AFEF),
    magenta: Color(0xFFC678DD),
    cyan: Color(0xFF56B6C2),
    white: Color(0xFFABB2BF),
    brightBlack: Color(0xFF5C6370),
    brightRed: Color(0xFFE06C75),
    brightGreen: Color(0xFF98C379),
    brightYellow: Color(0xFFE5C07B),
    brightBlue: Color(0xFF61AFEF),
    brightMagenta: Color(0xFFC678DD),
    brightCyan: Color(0xFF56B6C2),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFE5C07B),
    searchHitBackgroundCurrent: Color(0xFFE06C75),
    searchHitForeground: Color(0xFF282C34),
  );
}

/// 主题显示名称
class ThemeDisplayNames {
  static const Map<String, String> names = {
    'default': 'Default',
    'dracula': 'Dracula',
    'monokai': 'Monokai',
    'solarized_dark': 'Solarized Dark',
    'solarized_light': 'Solarized Light',
    'nord': 'Nord',
    'gruvbox': 'Gruvbox',
    'one_dark': 'One Dark',
  };

  static String getName(String key) => names[key] ?? key;
}
