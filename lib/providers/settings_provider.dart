import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../themes/terminal_themes.dart';
import 'package:xterm/xterm.dart';

/// 设置状态管理
/// 参考 termux-app: TermuxAppSharedPreferences.java
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  // 字体设置
  String _fontFamily = DefaultSettings.fontFamily;
  double _fontSize = DefaultSettings.fontSize;

  // 主题设置
  String _colorTheme = DefaultSettings.colorTheme;

  // 光标设置
  String _cursorStyle = DefaultSettings.cursorStyle;
  bool _cursorBlink = DefaultSettings.cursorBlink;

  // 显示设置
  bool _keepScreenOn = DefaultSettings.keepScreenOn;
  bool _showExtraKeys = DefaultSettings.showExtraKeys;
  int _terminalMargin = DefaultSettings.terminalMargin;

  // 输入设置
  bool _vibrationEnabled = DefaultSettings.vibrationEnabled;
  bool _bellEnabled = DefaultSettings.bellEnabled;

  // Getters
  bool get initialized => _initialized;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  String get colorTheme => _colorTheme;
  String get cursorStyle => _cursorStyle;
  bool get cursorBlink => _cursorBlink;
  bool get keepScreenOn => _keepScreenOn;
  bool get showExtraKeys => _showExtraKeys;
  int get terminalMargin => _terminalMargin;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get bellEnabled => _bellEnabled;

  TerminalTheme get terminalTheme => AppTerminalThemes.getTheme(_colorTheme);

  TerminalCursorType get terminalCursorType {
    switch (_cursorStyle) {
      case CursorStyles.underline:
        return TerminalCursorType.underline;
      case CursorStyles.bar:
        return TerminalCursorType.verticalBar;
      case CursorStyles.block:
      default:
        return TerminalCursorType.block;
    }
  }

  /// 初始化设置
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _initialized = true;
    notifyListeners();
  }

  /// 从 SharedPreferences 加载设置
  void _loadSettings() {
    _fontFamily = _prefs.getString('fontFamily') ?? DefaultSettings.fontFamily;
    _fontSize = _prefs.getDouble('fontSize') ?? DefaultSettings.fontSize;
    _colorTheme = _prefs.getString('colorTheme') ?? DefaultSettings.colorTheme;
    _cursorStyle = _prefs.getString('cursorStyle') ?? DefaultSettings.cursorStyle;
    _cursorBlink = _prefs.getBool('cursorBlink') ?? DefaultSettings.cursorBlink;
    _keepScreenOn = _prefs.getBool('keepScreenOn') ?? DefaultSettings.keepScreenOn;
    _showExtraKeys = _prefs.getBool('showExtraKeys') ?? DefaultSettings.showExtraKeys;
    _terminalMargin = _prefs.getInt('terminalMargin') ?? DefaultSettings.terminalMargin;
    _vibrationEnabled = _prefs.getBool('vibrationEnabled') ?? DefaultSettings.vibrationEnabled;
    _bellEnabled = _prefs.getBool('bellEnabled') ?? DefaultSettings.bellEnabled;
  }

  // Setters
  Future<void> setFontFamily(String value) async {
    _fontFamily = value;
    await _prefs.setString('fontFamily', value);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value.clamp(DefaultSettings.minFontSize, DefaultSettings.maxFontSize);
    await _prefs.setDouble('fontSize', _fontSize);
    notifyListeners();
  }

  Future<void> setColorTheme(String value) async {
    _colorTheme = value;
    await _prefs.setString('colorTheme', value);
    notifyListeners();
  }

  Future<void> setCursorStyle(String value) async {
    _cursorStyle = value;
    await _prefs.setString('cursorStyle', value);
    notifyListeners();
  }

  Future<void> setCursorBlink(bool value) async {
    _cursorBlink = value;
    await _prefs.setBool('cursorBlink', value);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    await _prefs.setBool('keepScreenOn', value);
    notifyListeners();
  }

  Future<void> setShowExtraKeys(bool value) async {
    _showExtraKeys = value;
    await _prefs.setBool('showExtraKeys', value);
    notifyListeners();
  }

  Future<void> setTerminalMargin(int value) async {
    _terminalMargin = value;
    await _prefs.setInt('terminalMargin', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs.setBool('vibrationEnabled', value);
    notifyListeners();
  }

  Future<void> setBellEnabled(bool value) async {
    _bellEnabled = value;
    await _prefs.setBool('bellEnabled', value);
    notifyListeners();
  }

  /// 重置为默认设置
  Future<void> resetToDefaults() async {
    await setFontFamily(DefaultSettings.fontFamily);
    await setFontSize(DefaultSettings.fontSize);
    await setColorTheme(DefaultSettings.colorTheme);
    await setCursorStyle(DefaultSettings.cursorStyle);
    await setCursorBlink(DefaultSettings.cursorBlink);
    await setKeepScreenOn(DefaultSettings.keepScreenOn);
    await setShowExtraKeys(DefaultSettings.showExtraKeys);
    await setTerminalMargin(DefaultSettings.terminalMargin);
    await setVibrationEnabled(DefaultSettings.vibrationEnabled);
    await setBellEnabled(DefaultSettings.bellEnabled);
  }
}
