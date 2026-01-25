import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// 终端颜色主题
/// 参考 termux-app: TerminalColorScheme.java

class AppTerminalThemes {
  static const Map<String, TerminalTheme> themes = {
    // Light Themes
    'github_light': _githubLightTheme,
    'one_light': _oneLightTheme,
    'tango_light': _tangoLightTheme,
    'solarized_light': _solarizedLightTheme,
    
    // Dark Themes
    'default': _defaultTheme,
    'github_dark': _githubDarkTheme,
    'tokyo_night': _tokyoNightTheme,
    'dracula': _draculaTheme,
    'monokai': _monokaiTheme,
    'one_dark': _oneDarkTheme,
    'material_dark': _materialDarkTheme,
    'nord': _nordTheme,
    'gruvbox': _gruvboxTheme,
    'solarized_dark': _solarizedDarkTheme,
  };

  static List<String> get themeNames => themes.keys.toList();

  static TerminalTheme getTheme(String name) {
    return themes[name] ?? _defaultTheme;
  }

  // --- Light Themes ---

  // GitHub Light
  static const _githubLightTheme = TerminalTheme(
    cursor: Color(0xFF044289),
    selection: Color(0x400366D6),
    foreground: Color(0xFF24292E),
    background: Color(0xFFFFFFFF),
    black: Color(0xFF24292E),
    red: Color(0xFFD73A49),
    green: Color(0xFF22863A),
    yellow: Color(0xFFB08800),
    blue: Color(0xFF0366D6),
    magenta: Color(0xFF6F42C1),
    cyan: Color(0xFF005CC5),
    white: Color(0xFFE1E4E8),
    brightBlack: Color(0xFF586069),
    brightRed: Color(0xFFCB2431),
    brightGreen: Color(0xFF28A745),
    brightYellow: Color(0xFFDBAB09),
    brightBlue: Color(0xFF2188FF),
    brightMagenta: Color(0xFF8A63D2),
    brightCyan: Color(0xFF0598DB),
    brightWhite: Color(0xFF959DA5),
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFFFF9632),
    searchHitForeground: Color(0xFF24292E),
  );

  // One Light
  static const _oneLightTheme = TerminalTheme(
    cursor: Color(0xFF528BFF),
    selection: Color(0x403E4451),
    foreground: Color(0xFF383A42),
    background: Color(0xFFFAFAFA),
    black: Color(0xFF383A42),
    red: Color(0xFFE45649),
    green: Color(0xFF50A14F),
    yellow: Color(0xFF986801),
    blue: Color(0xFF4078F2),
    magenta: Color(0xFFA626A4),
    cyan: Color(0xFF0184BC),
    white: Color(0xFFA0A1A7),
    brightBlack: Color(0xFF696C77),
    brightRed: Color(0xFFE45649),
    brightGreen: Color(0xFF50A14F),
    brightYellow: Color(0xFF986801),
    brightBlue: Color(0xFF4078F2),
    brightMagenta: Color(0xFFA626A4),
    brightCyan: Color(0xFF0184BC),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFE5C07B),
    searchHitBackgroundCurrent: Color(0xFFE06C75),
    searchHitForeground: Color(0xFF383A42),
  );

  // Tango Light
  static const _tangoLightTheme = TerminalTheme(
    cursor: Color(0xFF555555),
    selection: Color(0x40000000),
    foreground: Color(0xFF555753),
    background: Color(0xFFFFFFFF),
    black: Color(0xFF000000),
    red: Color(0xFFCC0000),
    green: Color(0xFF4E9A06),
    yellow: Color(0xFFC4A000),
    blue: Color(0xFF3465A4),
    magenta: Color(0xFF75507B),
    cyan: Color(0xFF06989A),
    white: Color(0xFFD3D7CF),
    brightBlack: Color(0xFF555753),
    brightRed: Color(0xFFEF2929),
    brightGreen: Color(0xFF8AE234),
    brightYellow: Color(0xFFFCE94F),
    brightBlue: Color(0xFF729FCF),
    brightMagenta: Color(0xFFAD7FA8),
    brightCyan: Color(0xFF34E2E2),
    brightWhite: Color(0xFFEEEEEC),
    searchHitBackground: Color(0xFFEF2929),
    searchHitBackgroundCurrent: Color(0xFFCC0000),
    searchHitForeground: Color(0xFFFFFFFF),
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

  // --- Dark Themes ---

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

  // GitHub Dark
  static const _githubDarkTheme = TerminalTheme(
    cursor: Color(0xFFC9D1D9),
    selection: Color(0x401F6FEB),
    foreground: Color(0xFFC9D1D9),
    background: Color(0xFF0D1117),
    black: Color(0xFF484F58),
    red: Color(0xFFFF7B72),
    green: Color(0xFF3FB950),
    yellow: Color(0xFFD29922),
    blue: Color(0xFF58A6FF),
    magenta: Color(0xFFBC8CFF),
    cyan: Color(0xFF39C5CF),
    white: Color(0xFFB1BAC4),
    brightBlack: Color(0xFF6E7681),
    brightRed: Color(0xFFFFA198),
    brightGreen: Color(0xFF56D364),
    brightYellow: Color(0xFFE3B341),
    brightBlue: Color(0xFF79C0FF),
    brightMagenta: Color(0xFFD2A8FF),
    brightCyan: Color(0xFF56D4DD),
    brightWhite: Color(0xFFF0F6FC),
    searchHitBackground: Color(0xFFF2CC60),
    searchHitBackgroundCurrent: Color(0xFFFFAB70),
    searchHitForeground: Color(0xFF0D1117),
  );

  // Tokyo Night
  static const _tokyoNightTheme = TerminalTheme(
    cursor: Color(0xFFC0CAF5),
    selection: Color(0x407AA2F7),
    foreground: Color(0xFFC0CAF5),
    background: Color(0xFF1A1B26),
    black: Color(0xFF15161E),
    red: Color(0xFFF7768E),
    green: Color(0xFF9ECE6A),
    yellow: Color(0xFFE0AF68),
    blue: Color(0xFF7AA2F7),
    magenta: Color(0xFFBB9AF7),
    cyan: Color(0xFF7DCFFF),
    white: Color(0xFFA9B1D6),
    brightBlack: Color(0xFF414868),
    brightRed: Color(0xFFF7768E),
    brightGreen: Color(0xFF9ECE6A),
    brightYellow: Color(0xFFE0AF68),
    brightBlue: Color(0xFF7AA2F7),
    brightMagenta: Color(0xFFBB9AF7),
    brightCyan: Color(0xFF7DCFFF),
    brightWhite: Color(0xFFC0CAF5),
    searchHitBackground: Color(0xFFE0AF68),
    searchHitBackgroundCurrent: Color(0xFFF7768E),
    searchHitForeground: Color(0xFF15161E),
  );

  // Material Dark
  static const _materialDarkTheme = TerminalTheme(
    cursor: Color(0xFFEEFFFF),
    selection: Color(0x40EEFFFF),
    foreground: Color(0xFFEEFFFF),
    background: Color(0xFF263238),
    black: Color(0xFF263238),
    red: Color(0xFFFF5370),
    green: Color(0xFFC3E88D),
    yellow: Color(0xFFFFCB6B),
    blue: Color(0xFF82AAFF),
    magenta: Color(0xFFC792EA),
    cyan: Color(0xFF89DDFF),
    white: Color(0xFFEEFFFF),
    brightBlack: Color(0xFF546E7A),
    brightRed: Color(0xFFFF5370),
    brightGreen: Color(0xFFC3E88D),
    brightYellow: Color(0xFFFFCB6B),
    brightBlue: Color(0xFF82AAFF),
    brightMagenta: Color(0xFFC792EA),
    brightCyan: Color(0xFF89DDFF),
    brightWhite: Color(0xFFEEFFFF),
    searchHitBackground: Color(0xFFFFCB6B),
    searchHitBackgroundCurrent: Color(0xFFFF5370),
    searchHitForeground: Color(0xFF263238),
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
    // Light
    'github_light': 'GitHub Light',
    'one_light': 'One Light',
    'tango_light': 'Tango Light',
    'solarized_light': 'Solarized Light',
    
    // Dark
    'default': 'Default (Termux)',
    'github_dark': 'GitHub Dark',
    'tokyo_night': 'Tokyo Night',
    'dracula': 'Dracula',
    'monokai': 'Monokai',
    'one_dark': 'One Dark',
    'material_dark': 'Material Dark',
    'nord': 'Nord',
    'gruvbox': 'Gruvbox',
    'solarized_dark': 'Solarized Dark',
  };

  static String getName(String key) => names[key] ?? key;
}
