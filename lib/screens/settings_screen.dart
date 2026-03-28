import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../themes/terminal_themes.dart';
import '../models/mirror.dart';
import '../utils/wcwidth_debug.dart';
import '../services/history_service.dart';
import '../services/api_service.dart';
import '../widgets/history_viewer.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════
// 主设置页面
// ═══════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Account
          const _AccountCard(),
          const SizedBox(height: 8),

          // Language (quick access)
          const _SettingsGroup(children: [_LanguageSetting()]),
          const SizedBox(height: 8),

          // Navigation tiles to sub-pages
          _SettingsGroup(
            children: [
              _NavTile(
                icon: Icons.palette_outlined,
                title: l10n.appearance,
                subtitle: _buildAppearanceSummary(context),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _AppearanceSettingsPage()),
                ),
              ),
              _NavTile(
                icon: Icons.terminal,
                title: l10n.terminal,
                subtitle: _buildTerminalSummary(context),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _TerminalSettingsPage()),
                ),
              ),
              _NavTile(
                icon: Icons.history,
                title: l10n.history,
                subtitle: null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _HistorySettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Shell & Package Sources
          _SettingsGroup(
            children: [
              const _ShellSetting(),
              Divider(
                  height: 1,
                  indent: 56,
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const _MirrorSetting(),
            ],
          ),
          const SizedBox(height: 8),

          // Advanced & About
          _SettingsGroup(
            children: [
              _NavTile(
                icon: Icons.tune,
                title: l10n.advanced,
                subtitle: null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _AdvancedSettingsPage()),
                ),
              ),
              Divider(
                  height: 1,
                  indent: 56,
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const _BackendServerTile(),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _buildAppearanceSummary(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final font = AvailableFonts.getDisplayName(settings.fontFamily,
        hasCustomFont: settings.customFontLoaded);
    final themeName = ThemeDisplayNames.getName(settings.colorTheme);
    return '$font, ${settings.fontSize.round()}pt, $themeName';
  }

  String _buildTerminalSummary(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (settings.keepScreenOn) parts.add(l10n.keepScreenOn);
    if (settings.showExtraKeys) parts.add(l10n.showExtraKeys);
    if (settings.cursorBlink) parts.add(l10n.cursorBlink);
    return parts.isEmpty ? '' : parts.join(', ');
  }
}

// ═══════════════════════════════════════════════════
// 通用 UI 组件
// ═══════════════════════════════════════════════════

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

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

// ═══════════════════════════════════════════════════
// Account Card
// ═══════════════════════════════════════════════════

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: authProvider.isLoggedIn
            ? _buildLoggedIn(context, authProvider, theme)
            : _buildLoggedOut(context, authProvider, theme),
      ),
    );
  }

  Widget _buildLoggedIn(
      BuildContext context, AuthProvider authProvider, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.person, color: theme.colorScheme.onPrimary),
      ),
      title: Text(authProvider.email ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Logged in'),
      trailing: TextButton(
        onPressed: () => _showLogoutDialog(context, authProvider),
        child: const Text('Logout'),
      ),
    );
  }

  Widget _buildLoggedOut(
      BuildContext context, AuthProvider authProvider, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person_outline,
            color: theme.colorScheme.onSurfaceVariant),
      ),
      title: const Text('Not logged in',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Login to sync SSH hosts and history'),
      trailing: FilledButton.tonal(
        onPressed: () {
          authProvider.requireLogin();
          Navigator.pop(context);
        },
        child: const Text('Login'),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Appearance Sub-page
// ═══════════════════════════════════════════════════

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearance)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _FontFamilySetting(),
          _FontSizeSetting(),
          _ColorThemeSetting(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Terminal Sub-page
// ═══════════════════════════════════════════════════

class _TerminalSettingsPage extends StatelessWidget {
  const _TerminalSettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.terminal)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.cursor),
          const _CursorStyleSetting(),
          const _CursorBlinkSetting(),
          _SectionHeader(title: l10n.display),
          const _KeepScreenOnSetting(),
          const _ShowExtraKeysSetting(),
          const _TerminalMarginSetting(),
          _SectionHeader(title: l10n.input),
          const _VibrationSetting(),
          const _BellSetting(),
          _SectionHeader(title: l10n.gestures),
          const _PinchZoomSetting(),
          const _VolumeUpKeySetting(),
          const _VolumeDownKeySetting(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// History Sub-page
// ═══════════════════════════════════════════════════

class _HistorySettingsPage extends StatelessWidget {
  const _HistorySettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: ListView(
        children: const [
          _HistoryStatsTile(),
          _HistoryViewerTile(),
          _ClearHistoryTile(),
          _ExportHistoryTile(),
          _ImportHistoryTile(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Advanced Sub-page
// ═══════════════════════════════════════════════════

class _AdvancedSettingsPage extends StatelessWidget {
  const _AdvancedSettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.advanced)),
      body: ListView(
        children: const [
          _ShowDebugInfoSetting(),
          _WcwidthDebugTile(),
          _ResetSettingsTile(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Individual Setting Widgets (unchanged logic)
// ═══════════════════════════════════════════════════

class _LanguageSetting extends StatelessWidget {
  const _LanguageSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(_getLocaleName(settings.locale)),
      onTap: () => _showLanguagePicker(context, settings),
    );
  }

  String _getLocaleName(Locale? locale) {
    if (locale == null) return 'System Default';
    switch ('${locale.languageCode}_${locale.countryCode ?? ''}') {
      case 'en_':
        return 'English';
      case 'zh_CN':
        return '简体中文';
      case 'zh_TW':
        return '繁體中文';
      default:
        return locale.toString();
    }
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _buildRadioTile(context, settings, null, 'System Default'),
            _buildRadioTile(context, settings, const Locale('en'), 'English'),
            _buildRadioTile(
                context, settings, const Locale('zh', 'CN'), '简体中文'),
            _buildRadioTile(
                context, settings, const Locale('zh', 'TW'), '繁體中文'),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile(
    BuildContext context,
    SettingsProvider settings,
    Locale? locale,
    String name,
  ) {
    bool isSelected;
    if (locale == null && settings.locale == null) {
      isSelected = true;
    } else if (locale != null && settings.locale != null) {
      isSelected = locale.languageCode == settings.locale!.languageCode &&
          locale.countryCode == settings.locale!.countryCode;
    } else {
      isSelected = false;
    }

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(name),
      onTap: () async {
        Navigator.pop(context);
        await settings.setLocale(locale);
      },
    );
  }
}

class _FontFamilySetting extends StatelessWidget {
  const _FontFamilySetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.font_download),
      title: Text(l10n.fontFamily),
      subtitle: Text(AvailableFonts.getDisplayName(
        settings.fontFamily,
        hasCustomFont: settings.customFontLoaded,
      )),
      onTap: () => _showFontPicker(context, settings),
    );
  }

  void _showFontPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).selectFont,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.star,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Built-in Nerd Fonts (support p10k icons)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: AvailableFonts.fonts.length,
                  itemBuilder: (context, index) {
                    final font = AvailableFonts.fonts[index];
                    final isSelected = font == settings.fontFamily;
                    final isBuiltInNerdFont =
                        AvailableFonts.isBuiltInNerdFont(font);

                    Widget? sectionHeader;
                    if (index == AvailableFonts.builtInNerdFonts.length) {
                      sectionHeader = Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_download,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 8),
                            Text(
                              'Google Fonts (no Powerline icons)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    TextStyle fontStyle;
                    if (isBuiltInNerdFont) {
                      final builtInFamily =
                          AvailableFonts.getBuiltInFontFamily(font);
                      fontStyle = TextStyle(fontFamily: builtInFamily);
                    } else {
                      try {
                        fontStyle = GoogleFonts.getFont(font);
                      } catch (e) {
                        fontStyle = const TextStyle();
                      }
                    }

                    final tile = ListTile(
                      leading: isBuiltInNerdFont
                          ? const Icon(Icons.terminal, size: 20)
                          : const Icon(Icons.text_fields, size: 20),
                      title: Text(font, style: fontStyle),
                      subtitle: isBuiltInNerdFont
                          ? Text('Preview: \uE0B0 \uE0B2 \uF113',
                              style: fontStyle.copyWith(fontSize: 12))
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        settings.setFontFamily(font);
                        Navigator.pop(context);
                      },
                    );

                    if (sectionHeader != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [sectionHeader, tile],
                      );
                    }
                    return tile;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeSetting extends StatelessWidget {
  const _FontSizeSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Text(l10n.fontSize),
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

class _ColorThemeSetting extends StatelessWidget {
  const _ColorThemeSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.palette),
      title: Text(l10n.colorTheme),
      subtitle: Text(ThemeDisplayNames.getName(settings.colorTheme)),
      onTap: () => _showThemePicker(context, settings),
    );
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectTheme,
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
                            color: Theme.of(context).colorScheme.outline),
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
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
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

class _CursorStyleSetting extends StatelessWidget {
  const _CursorStyleSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.edit),
      title: Text(l10n.cursorStyle),
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectCursorStyle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...CursorStyles.all.map((style) {
              final isSelected = style == settings.cursorStyle;
              return ListTile(
                leading: _buildCursorPreview(style, context),
                title: Text(_getCursorStyleName(style)),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
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
        return Container(width: 16, height: 24, color: color);
      case CursorStyles.underline:
        return Container(
          width: 16,
          height: 24,
          alignment: Alignment.bottomCenter,
          child: Container(width: 16, height: 3, color: color),
        );
      case CursorStyles.bar:
        return Container(
          width: 16,
          height: 24,
          alignment: Alignment.centerLeft,
          child: Container(width: 2, height: 24, color: color),
        );
      default:
        return const SizedBox(width: 16, height: 24);
    }
  }
}

class _CursorBlinkSetting extends StatelessWidget {
  const _CursorBlinkSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.flash_on),
      title: Text(l10n.cursorBlink),
      subtitle: Text(l10n.cursorBlinkDesc),
      value: settings.cursorBlink,
      onChanged: (value) => settings.setCursorBlink(value),
    );
  }
}

class _KeepScreenOnSetting extends StatelessWidget {
  const _KeepScreenOnSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.light_mode),
      title: Text(l10n.keepScreenOn),
      subtitle: Text(l10n.keepScreenOnDesc),
      value: settings.keepScreenOn,
      onChanged: (value) => settings.setKeepScreenOn(value),
    );
  }
}

class _ShowExtraKeysSetting extends StatelessWidget {
  const _ShowExtraKeysSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.keyboard),
      title: Text(l10n.showExtraKeys),
      subtitle: Text(l10n.showExtraKeysDesc),
      value: settings.showExtraKeys,
      onChanged: (value) => settings.setShowExtraKeys(value),
    );
  }
}

class _TerminalMarginSetting extends StatelessWidget {
  const _TerminalMarginSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.margin),
      title: Text(l10n.terminalMargin),
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

class _VibrationSetting extends StatelessWidget {
  const _VibrationSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.vibration),
      title: Text(l10n.vibration),
      subtitle: Text(l10n.vibrationDesc),
      value: settings.vibrationEnabled,
      onChanged: (value) => settings.setVibrationEnabled(value),
    );
  }
}

class _BellSetting extends StatelessWidget {
  const _BellSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.notifications),
      title: Text(l10n.bellSound),
      subtitle: Text(l10n.bellSoundDesc),
      value: settings.bellEnabled,
      onChanged: (value) => settings.setBellEnabled(value),
    );
  }
}

class _PinchZoomSetting extends StatelessWidget {
  const _PinchZoomSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.pinch),
      title: Text(l10n.pinchZoom),
      subtitle: Text(l10n.pinchZoomDesc),
      value: settings.pinchZoomEnabled,
      onChanged: (value) => settings.setPinchZoomEnabled(value),
    );
  }
}

class _VolumeUpKeySetting extends StatelessWidget {
  const _VolumeUpKeySetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.volume_up),
      title: Text(l10n.volumeUpKey),
      subtitle: Text(VolumeKeyActions.getDisplayName(settings.volumeUpAction)),
      onTap: () =>
          _VolumeKeyActionPicker.show(context, settings, isVolumeUp: true),
    );
  }
}

class _VolumeDownKeySetting extends StatelessWidget {
  const _VolumeDownKeySetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.volume_down),
      title: Text(l10n.volumeDownKey),
      subtitle:
          Text(VolumeKeyActions.getDisplayName(settings.volumeDownAction)),
      onTap: () =>
          _VolumeKeyActionPicker.show(context, settings, isVolumeUp: false),
    );
  }
}

class _VolumeKeyActionPicker {
  static void show(BuildContext context, SettingsProvider settings,
      {required bool isVolumeUp}) {
    final l10n = AppLocalizations.of(context);
    final currentAction =
        isVolumeUp ? settings.volumeUpAction : settings.volumeDownAction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectAction,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...VolumeKeyActions.presets.entries.map((entry) {
                      final actionId = entry.key;
                      final displayName = entry.value.$1;
                      final isSelected = currentAction == actionId;

                      return ListTile(
                        leading: Icon(
                          _getActionIcon(actionId),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(displayName),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (isVolumeUp) {
                            settings.setVolumeUpAction(actionId);
                          } else {
                            settings.setVolumeDownAction(actionId);
                          }
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.edit,
                        color: VolumeKeyActions.isCustom(currentAction)
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(l10n.customAction),
                      subtitle: VolumeKeyActions.isCustom(currentAction)
                          ? Text(
                              VolumeKeyActions.getCustomValue(currentAction) ??
                                  '')
                          : null,
                      trailing: VolumeKeyActions.isCustom(currentAction)
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _showCustomInputDialog(
                            context, settings, isVolumeUp, currentAction);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _getActionIcon(String actionId) {
    switch (actionId) {
      case 'ctrl':
        return Icons.keyboard_command_key;
      case 'alt':
        return Icons.alt_route;
      case 'esc':
        return Icons.exit_to_app;
      case 'tab':
        return Icons.keyboard_tab;
      case 'up':
        return Icons.arrow_upward;
      case 'down':
        return Icons.arrow_downward;
      case 'left':
        return Icons.arrow_back;
      case 'right':
        return Icons.arrow_forward;
      case 'pgup':
        return Icons.keyboard_double_arrow_up;
      case 'pgdn':
        return Icons.keyboard_double_arrow_down;
      case 'home':
        return Icons.first_page;
      case 'end':
        return Icons.last_page;
      case 'none':
        return Icons.block;
      default:
        return Icons.keyboard;
    }
  }

  static void _showCustomInputDialog(
    BuildContext context,
    SettingsProvider settings,
    bool isVolumeUp,
    String currentAction,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: VolumeKeyActions.getCustomValue(currentAction) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: l10n.customActionHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Examples:\n'
              '  \\x1b[A = Up arrow\n'
              '  \\x1b[B = Down arrow\n'
              '  \\t = Tab\n'
              '  \\x1b = Escape',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final customAction =
                  VolumeKeyActions.createCustomAction(controller.text);
              if (isVolumeUp) {
                settings.setVolumeUpAction(customAction);
              } else {
                settings.setVolumeDownAction(customAction);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _ResetSettingsTile extends StatelessWidget {
  const _ResetSettingsTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.restore),
      title: Text(l10n.resetToDefaults),
      subtitle: Text(l10n.resetToDefaultsDesc),
      onTap: () => _showResetConfirmation(context, settings),
    );
  }

  void _showResetConfirmation(BuildContext context, SettingsProvider settings) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetSettings),
        content: Text(l10n.resetSettingsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.resetToDefaults)),
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _MirrorSetting extends StatelessWidget {
  const _MirrorSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentMirror = settings.currentMirror;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.cloud_download),
      title: Text(l10n.packageMirror),
      subtitle: Text('${currentMirror.name} (${currentMirror.region})'),
      onTap: () => _showMirrorPicker(context, settings),
    );
  }

  void _showMirrorPicker(BuildContext context, SettingsProvider settings) {
    final mirrorsByRegion = AvailableMirrors.byRegion;
    final regions = mirrorsByRegion.keys.toList();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectMirror,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: regions.length,
                  itemBuilder: (context, regionIndex) {
                    final region = regions[regionIndex];
                    final mirrors = mirrorsByRegion[region]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            region,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ...mirrors.map((mirror) {
                          final isSelected = mirror.id == settings.mirrorId;
                          return ListTile(
                            leading: Icon(
                              _getRegionIcon(mirror.region),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(mirror.name),
                            subtitle: Text(
                              mirror.description.isNotEmpty
                                  ? mirror.description
                                  : mirror.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.primary)
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              _applyMirror(context, settings, mirror);
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRegionIcon(String region) {
    switch (region) {
      case 'Global':
        return Icons.public;
      case 'China':
        return Icons.flag;
      case 'Europe':
        return Icons.euro;
      case 'Europe/India':
        return Icons.language;
      case 'North America':
        return Icons.landscape;
      default:
        return Icons.cloud;
    }
  }

  void _applyMirror(
    BuildContext context,
    SettingsProvider settings,
    TermuxMirror mirror,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text('Switching to ${mirror.name}...')),
          ],
        ),
      ),
    );

    final success = await settings.setMirror(mirror.id);

    if (context.mounted) {
      Navigator.pop(context);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Mirror changed to ${mirror.name}'
                : 'Failed to change mirror',
          ),
          backgroundColor: success ? null : Colors.red,
        ),
      );
    }
  }
}

class _ShellSetting extends StatefulWidget {
  const _ShellSetting();

  @override
  State<_ShellSetting> createState() => _ShellSettingState();
}

class _ShellSettingState extends State<_ShellSetting> {
  Map<String, bool> _shellAvailability = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkShellAvailability();
  }

  Future<void> _checkShellAvailability() async {
    final availability = <String, bool>{};
    for (final entry in AvailableShells.shells.entries) {
      final shellPath = AvailableShells.getFullPath(entry.value);
      final exists = await File(shellPath).exists();
      availability[entry.value] = exists;
    }
    if (mounted) {
      setState(() {
        _shellAvailability = availability;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.terminal),
      title: Text(l10n.defaultShell),
      subtitle: Text(settings.defaultShellDisplayName),
      onTap: () => _showShellPicker(context, settings),
    );
  }

  void _showShellPicker(BuildContext context, SettingsProvider settings) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectShell,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else
              ...AvailableShells.shells.entries.map((entry) {
                final displayName = entry.key;
                final shellName = entry.value;
                final isSelected = shellName == settings.defaultShell;
                final isInstalled = _shellAvailability[shellName] ?? false;

                return ListTile(
                  leading: Icon(
                    _getShellIcon(shellName),
                    color: isInstalled
                        ? (isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null)
                        : Colors.grey,
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(color: isInstalled ? null : Colors.grey),
                  ),
                  subtitle: isInstalled
                      ? null
                      : Text(
                          l10n.shellNotInstalled,
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                        ),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: isInstalled
                      ? () async {
                          Navigator.pop(context);
                          await settings.setDefaultShell(shellName);
                          await _writeShellConfig(shellName);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Default shell changed to $displayName'),
                              ),
                            );
                          }
                        }
                      : null,
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _getShellIcon(String shellName) {
    switch (shellName) {
      case 'bash':
        return Icons.terminal;
      case 'zsh':
        return Icons.auto_awesome;
      case 'fish':
        return Icons.water;
      default:
        return Icons.code;
    }
  }

  Future<void> _writeShellConfig(String shellName) async {
    try {
      final homeDir = TermuxConstants.homeDir;
      final shellConfigFile = File('$homeDir/.shell');
      await shellConfigFile.writeAsString('$shellName\n');
      debugPrint('Written shell config to ~/.shell: $shellName');
    } catch (e) {
      debugPrint('Error writing ~/.shell: $e');
    }
  }
}

class _ShowDebugInfoSetting extends StatelessWidget {
  const _ShowDebugInfoSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.bug_report_outlined),
      title: Text(l10n.showDebugInfo),
      subtitle: Text(l10n.showDebugInfoDesc),
      value: settings.showDebugInfo,
      onChanged: (value) => settings.setShowDebugInfo(value),
    );
  }
}

class _WcwidthDebugTile extends StatelessWidget {
  const _WcwidthDebugTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.bug_report),
      title: Text(l10n.charWidthDebug),
      subtitle: Text(l10n.charWidthDebugDesc),
      onTap: () => _showFontTestDialog(context),
    );
  }

  void _showFontTestDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final fontFamily = settings.effectiveFontFamily;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font & Character Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Font family: $fontFamily',
                  style: const TextStyle(fontSize: 12)),
              Text('useBuiltInFont: ${settings.useBuiltInFont}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Powerline Arrows:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black,
                child: Text(
                  '>\uE0B0<  >\uE0B2<  >\uE0A0<',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 24,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
              const Text('Should show: >< >< ><',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text('Box Drawing:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black,
                child: Text(
                  '┌─────┐\n│test │\n└─────┘',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 18,
                    color: Colors.greenAccent,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nerd Font Icons:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black,
                child: Text(
                  '\uF07C Folder  \uF113 Git  \uF120 Term',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 18,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Compare monospace vs NerdFont:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'mono: >\uE0B0< (should show box)',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          color: Colors.yellow),
                    ),
                    Text(
                      'nerd: >\uE0B0< (should show arrow)',
                      style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 16,
                          color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'If both lines show empty between ><, the font\n'
                  'is NOT loading correctly. Try rebuilding the app.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDebugDialog(context);
            },
            child: const Text('Analyze Text'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Character Width Debug'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your prompt or enter text to analyze:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                style: TextStyle(
                  fontFamily: settings.effectiveFontFamily,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. ~/path > master  √ < 12:00',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick tests:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickTestButton(
                      label: 'Powerline',
                      text: '\uE0B0\uE0B1\uE0B2\uE0B3',
                      controller: controller),
                  _QuickTestButton(
                      label: 'Box Draw',
                      text: '┌─┬─┐│└─┴─┘',
                      controller: controller),
                  _QuickTestButton(
                      label: 'Block', text: '▀▄█▌▐░▒▓', controller: controller),
                  _QuickTestButton(
                      label: 'Git Icon',
                      text: '\uE0A0\uF113\uF126',
                      controller: controller),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text;
              if (text.isNotEmpty) {
                Navigator.pop(context);
                _showAnalysisResult(context, text, settings);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  void _showAnalysisResult(
    BuildContext context,
    String text,
    SettingsProvider settings,
  ) {
    final analysis = analyzeText(text);
    int totalWidth = 0;

    final buffer = StringBuffer();
    buffer.writeln('Input: "$text"');
    buffer.writeln('Codepoints: ${text.runes.length}');
    buffer.writeln('');
    buffer.writeln('Idx  Hex      Char  Width  Info');
    buffer.writeln('───  ───────  ────  ─────  ────');

    for (final item in analysis) {
      final idx = item['index'].toString().padLeft(3);
      final hex = item['hex'];
      final char = item['char'];
      final width = item['width'] as int;
      totalWidth += width;

      String flag = '';
      if (item['isPUA'] == true) flag = '[PUA]';
      if (item['isBox'] == true) flag = '[BOX]';
      if (item['isBlock'] == true) flag = '[BLK]';

      final name = item['name'] as String;
      final info = name.isNotEmpty ? '$name $flag' : flag;

      buffer.writeln('$idx  $hex  $char     $width      $info');
    }

    buffer.writeln('');
    buffer.writeln('Total calculated width: $totalWidth');
    buffer.writeln('');
    buffer.writeln('--- Potential Issues ---');

    bool hasIssue = false;
    for (final item in analysis) {
      final c = item['codepoint'] as int;
      final w = item['width'] as int;
      final hex = item['hex'];
      final char = item['char'];

      if (c >= 0xE0A0 && c <= 0xE0D4 && w != 1) {
        buffer.writeln('! $hex ($char): Powerline should be width 1, got $w');
        hasIssue = true;
      }

      if (c >= 0x2500 && c <= 0x257F && w != 1) {
        buffer.writeln('! $hex ($char): Box drawing should be width 1, got $w');
        hasIssue = true;
      }
    }

    if (!hasIssue) {
      buffer.writeln('No width calculation issues detected.');
      buffer.writeln('');
      buffer.writeln('If alignment is still wrong, the issue might be:');
      buffer.writeln('1. Font rendering width != calculated width');
      buffer.writeln('2. Shell (zsh) uses different wcwidth');
      buffer.writeln('3. Some characters missing in font');
    }

    final result = buffer.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Result'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  result,
                  style: TextStyle(
                    fontFamily: settings.effectiveFontFamily,
                    fontSize: 11,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _QuickTestButton extends StatelessWidget {
  final String label;
  final String text;
  final TextEditingController controller;

  const _QuickTestButton({
    required this.label,
    required this.text,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => controller.text = text,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ═══════════════════════════════════════════════════
// History Widgets
// ═══════════════════════════════════════════════════

class _HistoryStatsTile extends StatefulWidget {
  const _HistoryStatsTile();

  @override
  State<_HistoryStatsTile> createState() => _HistoryStatsTileState();
}

class _HistoryStatsTileState extends State<_HistoryStatsTile> {
  final _historyService = HistoryService();
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _historyService.getHistoryStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  Future<void> _showDebugInfo() async {
    final info = await _historyService.debugInfo();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('History Debug Info'),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(info),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(info),
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.analytics_outlined),
      title: Text(l10n.historyStats),
      subtitle: _stats == null
          ? Text(l10n.loading)
          : Text(
              '${_stats!['total']} commands (Bash: ${_stats!['bash']}, Zsh: ${_stats!['zsh']})'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.bug_report, size: 20),
            onPressed: _showDebugInfo,
            tooltip: l10n.historyDebugInfo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      onTap: _showDebugInfo,
    );
  }
}

class _HistoryViewerTile extends StatelessWidget {
  const _HistoryViewerTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(l10n.historyView),
      subtitle: Text(l10n.historyViewDesc),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => HistoryViewer.show(context),
    );
  }
}

class _ClearHistoryTile extends StatelessWidget {
  const _ClearHistoryTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.delete_outline),
      title: Text(l10n.historyClear),
      subtitle: Text(l10n.historyClearDesc),
      onTap: () => _showClearConfirmation(context),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.historyClear),
        content: Text(l10n.historyClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final historyService = HistoryService();
              await historyService.clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.historyCleared)),
                );
              }
            },
            child: Text(l10n.historyClear),
          ),
        ],
      ),
    );
  }
}

class _ExportHistoryTile extends StatelessWidget {
  const _ExportHistoryTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.file_upload_outlined),
      title: Text(l10n.historyExport),
      subtitle: Text(l10n.historyExportDesc),
      onTap: () => _exportHistory(context),
    );
  }

  Future<void> _exportHistory(BuildContext context) async {
    try {
      final historyService = HistoryService();

      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
        dir ??= await getApplicationDocumentsDirectory();
      } else {
        dir = await getDownloadsDirectory();
        dir ??= await getApplicationDocumentsDirectory();
      }

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'history_backup_$timestamp.json';
      final path = '${dir.path}/$fileName';

      final file = await historyService.exportHistory(path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: file.path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ImportHistoryTile extends StatelessWidget {
  const _ImportHistoryTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.file_download_outlined),
      title: Text(l10n.historyImport),
      subtitle: Text(l10n.historyImportDesc),
      onTap: () => _showImportDialog(context),
    );
  }

  void _showImportDialog(BuildContext context) {
    final pathController = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.historyImport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the path to the backup JSON file:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                hintText: '/path/to/history_backup.json',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose import mode:',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _importHistory(context, pathController.text, append: false);
            },
            child: const Text('Replace'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _importHistory(context, pathController.text, append: true);
            },
            child: const Text('Append'),
          ),
        ],
      ),
    );
  }

  Future<void> _importHistory(BuildContext context, String path,
      {required bool append}) async {
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a file path'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final historyService = HistoryService();
      final count = await historyService.importHistory(path, append: append);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              append
                  ? 'Appended $count commands to history'
                  : 'Imported $count commands (replaced existing)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BackendServerTile extends StatelessWidget {
  const _BackendServerTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backendDomain = ApiService.backendServer;
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(l10n.about),
      subtitle: Text(
        '${l10n.version}: ${AppConstants.version}\n'
        '${l10n.appIntro}\n'
        '${l10n.backendDomain}: $backendDomain',
      ),
    );
  }
}
