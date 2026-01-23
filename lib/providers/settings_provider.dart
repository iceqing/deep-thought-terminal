import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../themes/terminal_themes.dart';
import '../models/mirror.dart';
import 'package:xterm/xterm.dart';

/// 设置状态管理
/// 参考 termux-app: TermuxAppSharedPreferences.java
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  // 字体设置
  String _fontFamily = DefaultSettings.fontFamily;
  double _fontSize = DefaultSettings.fontSize;

  // 自定义字体支持
  bool _customFontLoaded = false;
  String _customFontPath = '';

  // 主题设置
  String _colorTheme = DefaultSettings.colorTheme;
  ThemeMode _themeMode = ThemeMode.system; // 默认为跟随系统

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

  // 手势设置
  bool _pinchZoomEnabled = DefaultSettings.pinchZoomEnabled;
  bool _volumeKeysEnabled = DefaultSettings.volumeKeysEnabled;

  // 镜像源设置
  String _mirrorId = 'default';

  // Getters
  bool get initialized => _initialized;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  bool get customFontLoaded => _customFontLoaded;

  /// 获取实际应该使用的字体族名称
  /// 优先级：自定义字体 > 内置 Nerd Font > Google Fonts
  String get effectiveFontFamily {
    // 如果有自定义字体，使用它
    if (_customFontLoaded) {
      return AvailableFonts.customFontFamily;
    }
    // 如果选择的是内置 Nerd Font（支持多种 Nerd Fonts）
    if (AvailableFonts.isBuiltInNerdFont(_fontFamily)) {
      return AvailableFonts.getBuiltInFontFamily(_fontFamily) ?? _fontFamily;
    }
    // 否则返回用户选择的字体（用于 Google Fonts）
    return _fontFamily;
  }

  /// 是否使用内置 Nerd Font（而不是 Google Fonts）
  bool get useBuiltInFont {
    if (_customFontLoaded) return true;
    return AvailableFonts.isBuiltInNerdFont(_fontFamily);
  }
  String get colorTheme => _colorTheme;
  ThemeMode get themeMode => _themeMode;
  String get cursorStyle => _cursorStyle;
  bool get cursorBlink => _cursorBlink;
  bool get keepScreenOn => _keepScreenOn;
  bool get showExtraKeys => _showExtraKeys;
  int get terminalMargin => _terminalMargin;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get bellEnabled => _bellEnabled;
  bool get pinchZoomEnabled => _pinchZoomEnabled;
  bool get volumeKeysEnabled => _volumeKeysEnabled;

  // 镜像源 Getters
  String get mirrorId => _mirrorId;
  TermuxMirror get currentMirror =>
      AvailableMirrors.getById(_mirrorId) ?? AvailableMirrors.defaultMirror;

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

    // 加载自定义字体（如果存在）
    await _loadCustomFont();

    _initialized = true;
    notifyListeners();
  }

  /// 获取自定义字体文件路径
  String get _customFontFilePath => '$_termuxConfigDir/font.ttf';

  /// 加载自定义字体（~/.termux/font.ttf）
  Future<void> _loadCustomFont() async {
    try {
      final fontFile = File(_customFontFilePath);
      if (await fontFile.exists() && await fontFile.length() > 0) {
        final bytes = await fontFile.readAsBytes();
        final fontLoader = FontLoader(AvailableFonts.customFontFamily);
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();
        _customFontLoaded = true;
        _customFontPath = _customFontFilePath;
        debugPrint('Custom font loaded from: $_customFontFilePath');
      } else {
        _customFontLoaded = false;
        debugPrint('No custom font found, using built-in Nerd Font');
      }
    } catch (e) {
      _customFontLoaded = false;
      debugPrint('Failed to load custom font: $e');
    }
  }

  /// 重新加载自定义字体
  Future<void> reloadCustomFont() async {
    await _loadCustomFont();
    notifyListeners();
  }

  /// 从 SharedPreferences 加载设置
  void _loadSettings() {
    _fontFamily = _prefs.getString('fontFamily') ?? DefaultSettings.fontFamily;
    _fontSize = _prefs.getDouble('fontSize') ?? DefaultSettings.fontSize;
    _colorTheme = _prefs.getString('colorTheme') ?? DefaultSettings.colorTheme;
    final themeModeIndex = _prefs.getInt('themeMode') ?? 0; // 0: system
    _themeMode = ThemeMode.values[themeModeIndex];
    _cursorStyle = _prefs.getString('cursorStyle') ?? DefaultSettings.cursorStyle;
    _cursorBlink = _prefs.getBool('cursorBlink') ?? DefaultSettings.cursorBlink;
    _keepScreenOn = _prefs.getBool('keepScreenOn') ?? DefaultSettings.keepScreenOn;
    _showExtraKeys = _prefs.getBool('showExtraKeys') ?? DefaultSettings.showExtraKeys;
    _terminalMargin = _prefs.getInt('terminalMargin') ?? DefaultSettings.terminalMargin;
    _vibrationEnabled = _prefs.getBool('vibrationEnabled') ?? DefaultSettings.vibrationEnabled;
    _bellEnabled = _prefs.getBool('bellEnabled') ?? DefaultSettings.bellEnabled;
    _pinchZoomEnabled = _prefs.getBool('pinchZoomEnabled') ?? DefaultSettings.pinchZoomEnabled;
    _volumeKeysEnabled = _prefs.getBool('volumeKeysEnabled') ?? DefaultSettings.volumeKeysEnabled;
    _mirrorId = _prefs.getString('mirrorId') ?? 'default';
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

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _prefs.setInt('themeMode', value.index);
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

  Future<void> setPinchZoomEnabled(bool value) async {
    _pinchZoomEnabled = value;
    await _prefs.setBool('pinchZoomEnabled', value);
    notifyListeners();
  }

  Future<void> setVolumeKeysEnabled(bool value) async {
    _volumeKeysEnabled = value;
    await _prefs.setBool('volumeKeysEnabled', value);
    notifyListeners();
  }

  /// 设置镜像源
  /// 会自动更新 sources.list 文件
  Future<bool> setMirror(String mirrorId) async {
    final mirror = AvailableMirrors.getById(mirrorId);
    if (mirror == null) return false;

    _mirrorId = mirrorId;
    await _prefs.setString('mirrorId', mirrorId);

    // 更新 sources.list 文件
    final success = await _updateSourcesList(mirror);

    notifyListeners();
    return success;
  }

  /// 更新 APT sources.list 文件
  Future<bool> _updateSourcesList(TermuxMirror mirror) async {
    try {
      final sourcesListPath = '$_termuxConfigDir/../usr/etc/apt/sources.list';
      final file = File(sourcesListPath);

      // 如果目录不存在，使用备用路径
      if (!await file.parent.exists()) {
        // Android 路径
        final altPath = Platform.isAndroid
            ? '/data/data/com.dpterm/files/usr/etc/apt/sources.list'
            : '${Platform.environment['HOME']}/.termux/../usr/etc/apt/sources.list';
        final altFile = File(altPath);
        if (await altFile.parent.exists()) {
          await altFile.writeAsString(mirror.sourcesListContent);
          debugPrint('Updated sources.list at: $altPath');
          return true;
        }
      } else {
        await file.writeAsString(mirror.sourcesListContent);
        debugPrint('Updated sources.list at: $sourcesListPath');
        return true;
      }

      debugPrint('Could not find sources.list directory');
      return false;
    } catch (e) {
      debugPrint('Failed to update sources.list: $e');
      return false;
    }
  }

  /// 获取 sources.list 文件路径
  static String get sourcesListPath {
    if (Platform.isAndroid) {
      return '/data/data/com.dpterm/files/usr/etc/apt/sources.list';
    } else {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/.termux/../usr/etc/apt/sources.list';
    }
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
    await setPinchZoomEnabled(DefaultSettings.pinchZoomEnabled);
    await setVolumeKeysEnabled(DefaultSettings.volumeKeysEnabled);
  }

  // ==================== termux-reload-settings 支持 ====================

  Timer? _reloadWatcher;
  StreamSubscription? _fileWatcher;

  /// 获取 termux 配置目录路径
  static String get _termuxConfigDir {
    if (Platform.isAndroid) {
      // Android: /data/data/com.dpterm/files/home/.termux
      final home = Platform.environment['HOME'] ?? '/data/data/com.dpterm/files/home';
      return '$home/.termux';
    } else {
      // Linux/其他: ~/.termux
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/.termux';
    }
  }

  /// 获取配置文件路径
  static String get _propertiesFilePath => '$_termuxConfigDir/termux.properties';

  /// 获取重载信号文件路径
  static String get _reloadSignalPath => '$_termuxConfigDir/.reload-settings';

  /// 启动设置重载监听
  void startReloadWatcher() {
    // 确保配置目录存在
    final configDir = Directory(_termuxConfigDir);
    if (!configDir.existsSync()) {
      try {
        configDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Failed to create termux config dir: $e');
      }
    }

    // 使用定时器定期检查信号文件（更可靠的方式）
    _reloadWatcher?.cancel();
    _reloadWatcher = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkReloadSignal();
    });

    debugPrint('Settings reload watcher started');
  }

  /// 停止设置重载监听
  void stopReloadWatcher() {
    _reloadWatcher?.cancel();
    _reloadWatcher = null;
    _fileWatcher?.cancel();
    _fileWatcher = null;
  }

  /// 检查重载信号文件
  void _checkReloadSignal() {
    final signalFile = File(_reloadSignalPath);
    if (signalFile.existsSync()) {
      debugPrint('Reload signal detected, reloading settings...');
      // 删除信号文件
      try {
        signalFile.deleteSync();
      } catch (e) {
        debugPrint('Failed to delete reload signal file: $e');
      }
      // 重载设置
      reloadFromPropertiesFile();
    }
  }

  /// 从 termux.properties 文件重载设置
  Future<void> reloadFromPropertiesFile() async {
    final propsFile = File(_propertiesFilePath);
    if (!propsFile.existsSync()) {
      debugPrint('No termux.properties file found');
      notifyListeners(); // 仍然通知以刷新 UI
      return;
    }

    try {
      final content = await propsFile.readAsString();
      final props = _parseProperties(content);

      // 应用设置
      await _applyProperties(props);

      debugPrint('Settings reloaded from termux.properties');
    } catch (e) {
      debugPrint('Failed to reload settings: $e');
    }
  }

  /// 解析 properties 文件格式
  Map<String, String> _parseProperties(String content) {
    final props = <String, String>{};
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      // 跳过空行和注释
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        final key = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        props[key] = value;
      }
    }

    return props;
  }

  /// 应用 properties 设置
  Future<void> _applyProperties(Map<String, String> props) async {
    // 字体大小
    if (props.containsKey('terminal-font-size')) {
      final size = double.tryParse(props['terminal-font-size']!);
      if (size != null) {
        await setFontSize(size);
      }
    }

    // 终端边距
    if (props.containsKey('terminal-margin-horizontal')) {
      final margin = int.tryParse(props['terminal-margin-horizontal']!);
      if (margin != null) {
        await setTerminalMargin(margin);
      }
    }

    // 额外按键显示
    if (props.containsKey('extra-keys')) {
      final value = props['extra-keys']!.toLowerCase();
      if (value == 'false' || value == 'none' || value == 'disable') {
        await setShowExtraKeys(false);
      } else {
        await setShowExtraKeys(true);
      }
    }

    // 震动
    if (props.containsKey('bell-character')) {
      final value = props['bell-character']!.toLowerCase();
      await setVibrationEnabled(value == 'vibrate');
      await setBellEnabled(value == 'beep');
    }

    // 光标样式
    if (props.containsKey('terminal-cursor-style')) {
      final style = props['terminal-cursor-style']!.toLowerCase();
      if (style == 'underline') {
        await setCursorStyle(CursorStyles.underline);
      } else if (style == 'bar' || style == 'ibeam') {
        await setCursorStyle(CursorStyles.bar);
      } else {
        await setCursorStyle(CursorStyles.block);
      }
    }

    // 光标闪烁
    if (props.containsKey('terminal-cursor-blink-rate')) {
      final rate = int.tryParse(props['terminal-cursor-blink-rate']!);
      await setCursorBlink(rate != null && rate > 0);
    }

    // 屏幕常亮
    if (props.containsKey('keep-screen-on')) {
      final value = props['keep-screen-on']!.toLowerCase();
      await setKeepScreenOn(value == 'true');
    }

    // 音量键
    if (props.containsKey('volume-keys')) {
      final value = props['volume-keys']!.toLowerCase();
      await setVolumeKeysEnabled(value != 'volume');
    }

    // 颜色主题（自定义扩展）
    if (props.containsKey('color-theme')) {
      await setColorTheme(props['color-theme']!);
    }

    // 字体（自定义扩展）
    if (props.containsKey('font-family')) {
      await setFontFamily(props['font-family']!);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stopReloadWatcher();
    super.dispose();
  }
}
