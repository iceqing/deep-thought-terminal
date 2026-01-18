import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../themes/terminal_themes.dart';

/// 设置页面
/// 参考 termux-app: SettingsActivity.java, TermuxPreferencesFragment.java
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: const [
          _SectionHeader(title: 'Appearance'),
          _FontFamilySetting(),
          _FontSizeSetting(),
          _ColorThemeSetting(),
          _SectionHeader(title: 'Cursor'),
          _CursorStyleSetting(),
          _CursorBlinkSetting(),
          _SectionHeader(title: 'Display'),
          _KeepScreenOnSetting(),
          _ShowExtraKeysSetting(),
          _TerminalMarginSetting(),
          _SectionHeader(title: 'Input'),
          _VibrationSetting(),
          _BellSetting(),
          _SectionHeader(title: 'Gestures'),
          _PinchZoomSetting(),
          _VolumeKeysSetting(),
          _SectionHeader(title: 'Advanced'),
          _ResetSettingsTile(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// 设置分区标题
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 字体选择
class _FontFamilySetting extends StatelessWidget {
  const _FontFamilySetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.font_download),
      title: const Text('Font Family'),
      subtitle: Text(settings.fontFamily),
      onTap: () => _showFontPicker(context, settings),
    );
  }

  void _showFontPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Font',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AvailableFonts.fonts.length,
                itemBuilder: (context, index) {
                  final font = AvailableFonts.fonts[index];
                  final isSelected = font == settings.fontFamily;

                  return ListTile(
                    title: Text(
                      font,
                      style: GoogleFonts.getFont(font),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      settings.setFontFamily(font);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 字体大小
class _FontSizeSetting extends StatelessWidget {
  const _FontSizeSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.format_size),
      title: const Text('Font Size'),
      subtitle: Text('${settings.fontSize.round()} pt'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: settings.fontSize,
          min: DefaultSettings.minFontSize,
          max: DefaultSettings.maxFontSize,
          divisions: 24,
          label: settings.fontSize.round().toString(),
          onChanged: (value) => settings.setFontSize(value),
        ),
      ),
    );
  }
}

/// 颜色主题
class _ColorThemeSetting extends StatelessWidget {
  const _ColorThemeSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('Color Theme'),
      subtitle: Text(ThemeDisplayNames.getName(settings.colorTheme)),
      onTap: () => _showThemePicker(context, settings),
    );
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Theme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AppTerminalThemes.themeNames.length,
                itemBuilder: (context, index) {
                  final themeName = AppTerminalThemes.themeNames[index];
                  final theme = AppTerminalThemes.getTheme(themeName);
                  final isSelected = themeName == settings.colorTheme;

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.background,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            color: theme.foreground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(ThemeDisplayNames.getName(themeName)),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      settings.setColorTheme(themeName);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 光标样式
class _CursorStyleSetting extends StatelessWidget {
  const _CursorStyleSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.edit),
      title: const Text('Cursor Style'),
      subtitle: Text(_getCursorStyleName(settings.cursorStyle)),
      onTap: () => _showCursorStylePicker(context, settings),
    );
  }

  String _getCursorStyleName(String style) {
    switch (style) {
      case CursorStyles.block:
        return 'Block';
      case CursorStyles.underline:
        return 'Underline';
      case CursorStyles.bar:
        return 'Bar';
      default:
        return style;
    }
  }

  void _showCursorStylePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Cursor Style',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...CursorStyles.all.map((style) {
              final isSelected = style == settings.cursorStyle;
              return ListTile(
                leading: _buildCursorPreview(style, context),
                title: Text(_getCursorStyleName(style)),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  settings.setCursorStyle(style);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCursorPreview(String style, BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    switch (style) {
      case CursorStyles.block:
        return Container(
          width: 16,
          height: 24,
          color: color,
        );
      case CursorStyles.underline:
        return Container(
          width: 16,
          height: 24,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 16,
            height: 3,
            color: color,
          ),
        );
      case CursorStyles.bar:
        return Container(
          width: 16,
          height: 24,
          alignment: Alignment.centerLeft,
          child: Container(
            width: 2,
            height: 24,
            color: color,
          ),
        );
      default:
        return const SizedBox(width: 16, height: 24);
    }
  }
}

/// 光标闪烁
class _CursorBlinkSetting extends StatelessWidget {
  const _CursorBlinkSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.flash_on),
      title: const Text('Cursor Blink'),
      subtitle: const Text('Animate cursor blinking'),
      value: settings.cursorBlink,
      onChanged: (value) => settings.setCursorBlink(value),
    );
  }
}

/// 屏幕常亮
class _KeepScreenOnSetting extends StatelessWidget {
  const _KeepScreenOnSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.light_mode),
      title: const Text('Keep Screen On'),
      subtitle: const Text('Prevent screen from turning off'),
      value: settings.keepScreenOn,
      onChanged: (value) => settings.setKeepScreenOn(value),
    );
  }
}

/// 显示额外按键
class _ShowExtraKeysSetting extends StatelessWidget {
  const _ShowExtraKeysSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.keyboard),
      title: const Text('Show Extra Keys'),
      subtitle: const Text('Show additional keyboard row'),
      value: settings.showExtraKeys,
      onChanged: (value) => settings.setShowExtraKeys(value),
    );
  }
}

/// 终端边距
class _TerminalMarginSetting extends StatelessWidget {
  const _TerminalMarginSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.margin),
      title: const Text('Terminal Margin'),
      subtitle: Text('${settings.terminalMargin} px'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: settings.terminalMargin.toDouble(),
          min: 0,
          max: 32,
          divisions: 8,
          label: settings.terminalMargin.toString(),
          onChanged: (value) => settings.setTerminalMargin(value.round()),
        ),
      ),
    );
  }
}

/// 振动反馈
class _VibrationSetting extends StatelessWidget {
  const _VibrationSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.vibration),
      title: const Text('Vibration'),
      subtitle: const Text('Haptic feedback on key press'),
      value: settings.vibrationEnabled,
      onChanged: (value) => settings.setVibrationEnabled(value),
    );
  }
}

/// 响铃
class _BellSetting extends StatelessWidget {
  const _BellSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.notifications),
      title: const Text('Bell'),
      subtitle: const Text('Play sound on bell character'),
      value: settings.bellEnabled,
      onChanged: (value) => settings.setBellEnabled(value),
    );
  }
}

/// 双指缩放
class _PinchZoomSetting extends StatelessWidget {
  const _PinchZoomSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.pinch),
      title: const Text('Pinch to Zoom'),
      subtitle: const Text('Use two fingers to resize text'),
      value: settings.pinchZoomEnabled,
      onChanged: (value) => settings.setPinchZoomEnabled(value),
    );
  }
}

/// 音量键作为修饰键
class _VolumeKeysSetting extends StatelessWidget {
  const _VolumeKeysSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SwitchListTile(
      secondary: const Icon(Icons.volume_up),
      title: const Text('Volume Keys as Modifiers'),
      subtitle: const Text('Vol+ = Ctrl, Vol- = Alt'),
      value: settings.volumeKeysEnabled,
      onChanged: (value) => settings.setVolumeKeysEnabled(value),
    );
  }
}

/// 重置设置
class _ResetSettingsTile extends StatelessWidget {
  const _ResetSettingsTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    return ListTile(
      leading: const Icon(Icons.restore),
      title: const Text('Reset to Defaults'),
      subtitle: const Text('Restore all settings to default values'),
      onTap: () => _showResetConfirmation(context, settings),
    );
  }

  void _showResetConfirmation(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
