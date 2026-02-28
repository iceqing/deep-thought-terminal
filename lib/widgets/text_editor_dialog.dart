import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/a11y-dark.dart';
import 'package:re_highlight/styles/a11y-light.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/monokai.dart';
import 'package:re_highlight/styles/tokyo-night-dark.dart';
import 'package:re_highlight/styles/tokyo-night-light.dart';
import 'package:re_highlight/styles/vs.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextEditorDialog extends StatefulWidget {
  final String fileName;
  final String initialContent;
  final Future<void> Function(String) onSave;

  const TextEditorDialog({
    super.key,
    required this.fileName,
    required this.initialContent,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required String initialContent,
    required Future<void> Function(String) onSave,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => TextEditorDialog(
          fileName: fileName,
          initialContent: initialContent,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  static const String _prefShowLineNumbers = 'editor_show_line_numbers';
  static const String _prefFontSize = 'editor_font_size';
  static const String _prefWordWrap = 'editor_word_wrap';
  static const String _prefTheme = 'editor_theme';

  late CodeLineEditingController _editorController;
  late CodeFindController _findController;

  bool _hasChanges = false;
  bool _isSaving = false;
  bool _showLineNumbers = true;
  bool _wordWrap = true;
  double _fontSize = 14.0;
  double _scaleStartFontSize = 14.0;
  String _themeId = 'auto';

  static const List<_EditorThemeOption> _themeOptions = [
    _EditorThemeOption('auto', '跟随系统'),
    _EditorThemeOption('vscode_light', 'VS Code Light'),
    _EditorThemeOption('vscode_dark', 'VS Code Dark'),
    _EditorThemeOption('github_light', 'GitHub Light'),
    _EditorThemeOption('github_dark', 'GitHub Dark'),
    _EditorThemeOption('atom_light', 'Atom One Light'),
    _EditorThemeOption('atom_dark', 'Atom One Dark'),
    _EditorThemeOption('tokyo_light', 'Tokyo Night Light'),
    _EditorThemeOption('tokyo_dark', 'Tokyo Night Dark'),
    _EditorThemeOption('a11y_light', 'A11y Light'),
    _EditorThemeOption('a11y_dark', 'A11y Dark'),
    _EditorThemeOption('monokai_dark', 'Monokai Dark'),
  ];

  static final Map<String, _EditorVisualTheme> _editorThemes = {
    'vscode_light': const _EditorVisualTheme(
      syntaxTheme: vsTheme,
      editorBackground: Color(0xFFFFFFFF),
      panelBackground: Color(0xFFF3F3F3),
      panelBorder: Color(0xFFDADADA),
      textColor: Color(0xFF1E1E1E),
      mutedTextColor: Color(0xFF6B6B6B),
      primaryColor: Color(0xFF0B57D0),
      selectionColor: Color(0x290B57D0),
      cursorColor: Color(0xFF005FB8),
    ),
    'vscode_dark': const _EditorVisualTheme(
      syntaxTheme: vs2015Theme,
      editorBackground: Color(0xFF1E1E1E),
      panelBackground: Color(0xFF252526),
      panelBorder: Color(0xFF3C3C3C),
      textColor: Color(0xFFD4D4D4),
      mutedTextColor: Color(0xFF9DA1A6),
      primaryColor: Color(0xFF569CD6),
      selectionColor: Color(0xFF264F78),
      cursorColor: Color(0xFFA6E3FF),
    ),
    'github_light': const _EditorVisualTheme(
      syntaxTheme: githubTheme,
      editorBackground: Color(0xFFFFFFFF),
      panelBackground: Color(0xFFF6F8FA),
      panelBorder: Color(0xFFD0D7DE),
      textColor: Color(0xFF24292F),
      mutedTextColor: Color(0xFF57606A),
      primaryColor: Color(0xFF0969DA),
      selectionColor: Color(0x290969DA),
      cursorColor: Color(0xFF0969DA),
    ),
    'github_dark': const _EditorVisualTheme(
      syntaxTheme: githubDarkTheme,
      editorBackground: Color(0xFF0D1117),
      panelBackground: Color(0xFF161B22),
      panelBorder: Color(0xFF30363D),
      textColor: Color(0xFFC9D1D9),
      mutedTextColor: Color(0xFF8B949E),
      primaryColor: Color(0xFF58A6FF),
      selectionColor: Color(0xFF264F78),
      cursorColor: Color(0xFF58A6FF),
    ),
    'atom_light': const _EditorVisualTheme(
      syntaxTheme: atomOneLightTheme,
      editorBackground: Color(0xFFFAFAFA),
      panelBackground: Color(0xFFF0F0F0),
      panelBorder: Color(0xFFDDDDDD),
      textColor: Color(0xFF383A42),
      mutedTextColor: Color(0xFF7A7E87),
      primaryColor: Color(0xFF4078F2),
      selectionColor: Color(0x294078F2),
      cursorColor: Color(0xFF4078F2),
    ),
    'atom_dark': const _EditorVisualTheme(
      syntaxTheme: atomOneDarkTheme,
      editorBackground: Color(0xFF282C34),
      panelBackground: Color(0xFF21252B),
      panelBorder: Color(0xFF3B4048),
      textColor: Color(0xFFABB2BF),
      mutedTextColor: Color(0xFF7F848E),
      primaryColor: Color(0xFF61AFEF),
      selectionColor: Color(0xFF3E4451),
      cursorColor: Color(0xFF61AFEF),
    ),
    'tokyo_light': const _EditorVisualTheme(
      syntaxTheme: tokyoNightLightTheme,
      editorBackground: Color(0xFFD5D6DB),
      panelBackground: Color(0xFFC7C8CF),
      panelBorder: Color(0xFFB4B5BC),
      textColor: Color(0xFF565A6E),
      mutedTextColor: Color(0xFF7B7F92),
      primaryColor: Color(0xFF34548A),
      selectionColor: Color(0x2934548A),
      cursorColor: Color(0xFF34548A),
    ),
    'tokyo_dark': const _EditorVisualTheme(
      syntaxTheme: tokyoNightDarkTheme,
      editorBackground: Color(0xFF1A1B26),
      panelBackground: Color(0xFF16161E),
      panelBorder: Color(0xFF2A2E3D),
      textColor: Color(0xFFC0CAF5),
      mutedTextColor: Color(0xFF7A85B7),
      primaryColor: Color(0xFF7AA2F7),
      selectionColor: Color(0xFF283457),
      cursorColor: Color(0xFF7AA2F7),
    ),
    'a11y_light': const _EditorVisualTheme(
      syntaxTheme: a11YLightTheme,
      editorBackground: Color(0xFFF8F8F8),
      panelBackground: Color(0xFFEEEEEE),
      panelBorder: Color(0xFFD6D6D6),
      textColor: Color(0xFF1A1A1A),
      mutedTextColor: Color(0xFF5C5C5C),
      primaryColor: Color(0xFF005A9C),
      selectionColor: Color(0x29005A9C),
      cursorColor: Color(0xFF005A9C),
    ),
    'a11y_dark': const _EditorVisualTheme(
      syntaxTheme: a11YDarkTheme,
      editorBackground: Color(0xFF2B2B2B),
      panelBackground: Color(0xFF1F1F1F),
      panelBorder: Color(0xFF434343),
      textColor: Color(0xFFF8F8F2),
      mutedTextColor: Color(0xFFB0B0B0),
      primaryColor: Color(0xFFFFD866),
      selectionColor: Color(0xFF4D4D4D),
      cursorColor: Color(0xFFFFD866),
    ),
    'monokai_dark': const _EditorVisualTheme(
      syntaxTheme: monokaiTheme,
      editorBackground: Color(0xFF272822),
      panelBackground: Color(0xFF1E1F1C),
      panelBorder: Color(0xFF3E3D32),
      textColor: Color(0xFFF8F8F2),
      mutedTextColor: Color(0xFFA6A28C),
      primaryColor: Color(0xFFA6E22E),
      selectionColor: Color(0xFF49483E),
      cursorColor: Color(0xFFF8F8F2),
    ),
  };

  @override
  void initState() {
    super.initState();
    _editorController =
        CodeLineEditingController.fromText(widget.initialContent);
    _findController = CodeFindController(_editorController);
    _editorController.addListener(_onTextChanged);
    _loadEditorPreferences();
  }

  @override
  void dispose() {
    _editorController.removeListener(_onTextChanged);
    _editorController.dispose();
    _findController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges = _editorController.text != widget.initialContent;
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _loadEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showLines = prefs.getBool(_prefShowLineNumbers);
      final size = prefs.getDouble(_prefFontSize);
      final wrap = prefs.getBool(_prefWordWrap);
      final theme = prefs.getString(_prefTheme);
      if (!mounted) return;
      final validatedTheme = _normalizeThemeId(
        theme,
        Theme.of(context).brightness,
      );
      setState(() {
        _showLineNumbers = showLines ?? true;
        _fontSize = (size ?? 14.0).clamp(10.0, 28.0);
        _wordWrap = wrap ?? true;
        _themeId = validatedTheme;
      });
    } catch (_) {
      // Keep defaults when preference load fails.
    }
  }

  Future<void> _saveEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefShowLineNumbers, _showLineNumbers);
      await prefs.setDouble(_prefFontSize, _fontSize);
      await prefs.setBool(_prefWordWrap, _wordWrap);
      await prefs.setString(_prefTheme, _themeId);
    } catch (_) {
      // Ignore preference save failures.
    }
  }

  String _normalizeThemeId(String? savedThemeId, Brightness brightness) {
    if (savedThemeId == null || savedThemeId.isEmpty) return 'auto';
    if (_themeOptions.any((option) => option.id == savedThemeId)) {
      return savedThemeId;
    }

    // Backward compatibility for old IDs.
    switch (savedThemeId) {
      case 'atom':
        return brightness == Brightness.dark ? 'atom_dark' : 'atom_light';
      case 'github':
        return brightness == Brightness.dark ? 'github_dark' : 'github_light';
      case 'a11y':
        return brightness == Brightness.dark ? 'a11y_dark' : 'a11y_light';
      default:
        return 'auto';
    }
  }

  Future<void> _showEditorSettings() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.tune, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('编辑器设置', style: theme.textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _themeOptions.any((o) => o.id == _themeId)
                            ? _themeId
                            : 'auto',
                        decoration: InputDecoration(
                          labelText: '编辑器主题',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _themeOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.id,
                                child: Row(
                                  children: [
                                    _ThemePreviewDots(
                                      themeId: option.id,
                                      themes: _editorThemes,
                                      systemBrightness: theme.brightness,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(option.label),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _themeId = value);
                          setSheetState(() {});
                          _saveEditorPreferences();
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('显示行号'),
                        secondary: const Icon(Icons.format_list_numbered),
                        value: _showLineNumbers,
                        onChanged: (value) {
                          setState(() => _showLineNumbers = value);
                          setSheetState(() {});
                          _saveEditorPreferences();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动换行'),
                        secondary: const Icon(Icons.wrap_text),
                        value: _wordWrap,
                        onChanged: (value) {
                          setState(() => _wordWrap = value);
                          setSheetState(() {});
                          _saveEditorPreferences();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.text_fields, size: 24),
                          const SizedBox(width: 16),
                          const Text('字体大小'),
                          Expanded(
                            child: Slider(
                              min: 10,
                              max: 28,
                              divisions: 18,
                              label: _fontSize.toStringAsFixed(0),
                              value: _fontSize,
                              onChanged: (value) {
                                setState(() => _fontSize = value);
                                setSheetState(() {});
                              },
                              onChangeEnd: (_) => _saveEditorPreferences(),
                            ),
                          ),
                          Text(
                            _fontSize.toStringAsFixed(0),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '支持双指缩放字体',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(_editorController.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('您有尚未保存的更改。确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('放弃'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartFontSize = _fontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final next = (_scaleStartFontSize * details.scale).clamp(10.0, 28.0);
    if ((next - _fontSize).abs() < 0.2) return;
    setState(() {
      _fontSize = next;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _saveEditorPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editorTheme = _resolveEditorTheme(theme.brightness);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: editorTheme.editorBackground,
        appBar: AppBar(
          backgroundColor: editorTheme.panelBackground,
          foregroundColor: editorTheme.textColor,
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasChanges)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (!shouldPop || !context.mounted) return;
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: _hasChanges ? _save : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: _hasChanges
                        ? editorTheme.primaryColor
                        : editorTheme.mutedTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'find') {
                  _findController.findMode();
                } else if (value == 'settings') {
                  _showEditorSettings();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'find',
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20),
                      SizedBox(width: 12),
                      Text('查找与替换'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('编辑器设置'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ColoredBox(
                  color: theme.colorScheme.surface,
                  child: CodeEditor(
                    controller: _editorController,
                    findController: _findController,
                    findBuilder: (context, controller, readOnly) {
                      return _EditorFindPanel(
                        controller: controller,
                        readOnly: readOnly,
                        themeSpec: editorTheme,
                      );
                    },
                    wordWrap: _wordWrap,
                    style: _buildEditorStyle(editorTheme),
                    indicatorBuilder: _showLineNumbers
                        ? (context, editingController, chunkController,
                            notifier) {
                            return DefaultCodeLineNumber(
                              controller: editingController,
                              notifier: notifier,
                            );
                          }
                        : null,
                    sperator: _showLineNumbers
                        ? Container(
                            width: 1,
                            color:
                                editorTheme.panelBorder.withValues(alpha: 0.7),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            _buildBottomToolbar(editorTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(_EditorVisualTheme editorTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: editorTheme.panelBackground,
        border: Border(
          top: BorderSide(
            color: editorTheme.panelBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo, size: 20),
              tooltip: '撤销',
              color: editorTheme.textColor,
              onPressed: () => _editorController.undo(),
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 20),
              tooltip: '重做',
              color: editorTheme.textColor,
              onPressed: () => _editorController.redo(),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.keyboard_tab, size: 20),
              tooltip: '缩进',
              color: editorTheme.textColor,
              onPressed: () {
                _editorController.replaceSelection('    ');
              },
            ),
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: '查找',
              color: editorTheme.textColor,
              onPressed: () => _findController.findMode(),
            ),
          ],
        ),
      ),
    );
  }

  CodeEditorStyle _buildEditorStyle(_EditorVisualTheme editorTheme) {
    return CodeEditorStyle(
      fontSize: _fontSize,
      fontFamily: 'JetBrainsMonoNerdFontMono',
      fontHeight: 1.55,
      backgroundColor: editorTheme.editorBackground,
      textColor: editorTheme.textColor,
      selectionColor: editorTheme.selectionColor,
      cursorColor: editorTheme.cursorColor,
      codeTheme: _buildCodeTheme(editorTheme),
    );
  }

  CodeHighlightTheme? _buildCodeTheme(_EditorVisualTheme editorTheme) {
    final language = _languageByFileName(widget.fileName);
    if (language == null) return null;

    return CodeHighlightTheme(
      languages: {language.name: CodeHighlightThemeMode(mode: language.mode)},
      theme: editorTheme.syntaxTheme,
    );
  }

  _EditorVisualTheme _resolveEditorTheme(Brightness systemBrightness) {
    switch (_themeId) {
      case 'atom':
        return systemBrightness == Brightness.dark
            ? _editorThemes['atom_dark']!
            : _editorThemes['atom_light']!;
      case 'github':
        return systemBrightness == Brightness.dark
            ? _editorThemes['github_dark']!
            : _editorThemes['github_light']!;
      case 'a11y':
        return systemBrightness == Brightness.dark
            ? _editorThemes['a11y_dark']!
            : _editorThemes['a11y_light']!;
      case 'auto':
        return systemBrightness == Brightness.dark
            ? _editorThemes['vscode_dark']!
            : _editorThemes['vscode_light']!;
      default:
        return _editorThemes[_themeId] ??
            (systemBrightness == Brightness.dark
                ? _editorThemes['vscode_dark']!
                : _editorThemes['vscode_light']!);
    }
  }

  _LanguageMode? _languageByFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.bashrc') ||
        lower.endsWith('.bash_history') ||
        lower.endsWith('.profile') ||
        lower.endsWith('.zshrc') ||
        lower.endsWith('.zprofile')) {
      return _LanguageMode('shell', langShell);
    }

    final dot = lower.lastIndexOf('.');
    if (dot == -1 || dot == lower.length - 1) {
      return null;
    }

    final ext = lower.substring(dot + 1);
    switch (ext) {
      case 'dart':
        return _LanguageMode('dart', langDart);
      case 'json':
        return _LanguageMode('json', langJson);
      case 'yaml':
      case 'yml':
        return _LanguageMode('yaml', langYaml);
      case 'xml':
      case 'svg':
      case 'plist':
        return _LanguageMode('xml', langXml);
      case 'md':
      case 'markdown':
        return _LanguageMode('markdown', langMarkdown);
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'ksh':
        return _LanguageMode('bash', langBash);
      case 'toml':
      case 'ini':
      case 'cfg':
      case 'conf':
        return _LanguageMode('ini', langIni);
      case 'properties':
        return _LanguageMode('properties', langProperties);
      case 'py':
        return _LanguageMode('python', langPython);
      case 'js':
      case 'mjs':
      case 'cjs':
        return _LanguageMode('javascript', langJavascript);
      case 'ts':
        return _LanguageMode('typescript', langTypescript);
      case 'css':
      case 'scss':
      case 'less':
        return _LanguageMode('css', langCss);
      case 'java':
        return _LanguageMode('java', langJava);
      case 'kt':
      case 'kts':
        return _LanguageMode('kotlin', langKotlin);
      case 'go':
        return _LanguageMode('go', langGo);
      case 'rs':
        return _LanguageMode('rust', langRust);
      case 'sql':
        return _LanguageMode('sql', langSql);
      case 'c':
      case 'h':
        return _LanguageMode('c', langC);
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'hpp':
        return _LanguageMode('cpp', langCpp);
      case 'php':
        return _LanguageMode('php', langPhp);
      case 'rb':
        return _LanguageMode('ruby', langRuby);
      case 'swift':
        return _LanguageMode('swift', langSwift);
      case 'html':
      case 'htm':
        return _LanguageMode('xml', langXml);
      default:
        return null;
    }
  }
}

class _LanguageMode {
  final String name;
  final Mode mode;

  const _LanguageMode(this.name, this.mode);
}

class _EditorThemeOption {
  final String id;
  final String label;

  const _EditorThemeOption(this.id, this.label);
}

class _EditorVisualTheme {
  final Map<String, TextStyle> syntaxTheme;
  final Color editorBackground;
  final Color panelBackground;
  final Color panelBorder;
  final Color textColor;
  final Color mutedTextColor;
  final Color primaryColor;
  final Color selectionColor;
  final Color cursorColor;

  const _EditorVisualTheme({
    required this.syntaxTheme,
    required this.editorBackground,
    required this.panelBackground,
    required this.panelBorder,
    required this.textColor,
    required this.mutedTextColor,
    required this.primaryColor,
    required this.selectionColor,
    required this.cursorColor,
  });
}

class _ThemePreviewDots extends StatelessWidget {
  final String themeId;
  final Map<String, _EditorVisualTheme> themes;
  final Brightness systemBrightness;

  const _ThemePreviewDots({
    required this.themeId,
    required this.themes,
    required this.systemBrightness,
  });

  @override
  Widget build(BuildContext context) {
    final showDual = themeId == 'auto';
    final primary = _resolveThemeForPreview(themeId, preferDark: false);
    final secondary =
        showDual ? _resolveThemeForPreview(themeId, preferDark: true) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _singleSwatch(primary),
        if (secondary != null) const SizedBox(width: 6),
        if (secondary != null) _singleSwatch(secondary),
      ],
    );
  }

  Widget _singleSwatch(_EditorVisualTheme theme) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: theme.editorBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: theme.panelBorder, width: 1),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  _EditorVisualTheme _resolveThemeForPreview(String id,
      {required bool preferDark}) {
    switch (id) {
      case 'auto':
        return preferDark ? themes['vscode_dark']! : themes['vscode_light']!;
      case 'atom':
        return preferDark ? themes['atom_dark']! : themes['atom_light']!;
      case 'github':
        return preferDark ? themes['github_dark']! : themes['github_light']!;
      case 'a11y':
        return preferDark ? themes['a11y_dark']! : themes['a11y_light']!;
      default:
        final single = themes[id];
        if (single != null) return single;
        return systemBrightness == Brightness.dark
            ? themes['vscode_dark']!
            : themes['vscode_light']!;
    }
  }
}

class _EditorFindPanel extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final bool readOnly;
  final _EditorVisualTheme themeSpec;

  const _EditorFindPanel({
    required this.controller,
    required this.readOnly,
    required this.themeSpec,
  });

  @override
  Size get preferredSize {
    final value = controller.value;
    if (value == null) return Size.zero;
    return Size.fromHeight(value.replaceMode ? 100 : 56);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = controller.value;
    if (value == null) {
      return const SizedBox.shrink();
    }

    final resultText = value.result == null
        ? '0/0'
        : '${value.result!.index + 1}/${value.result!.matches.length}';

    return Container(
      decoration: BoxDecoration(
        color: themeSpec.panelBackground,
        border: Border(
          bottom: BorderSide(
            color: themeSpec.panelBorder,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  value.replaceMode
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: themeSpec.primaryColor,
                ),
                onPressed: () {
                  if (value.replaceMode) {
                    controller.findMode();
                  } else {
                    controller.replaceMode();
                  }
                },
                tooltip: '切换替换模式',
              ),
              Expanded(
                child: TextField(
                  controller: controller.findInputController,
                  focusNode: controller.findInputFocusNode,
                  style: TextStyle(fontSize: 14, color: themeSpec.textColor),
                  cursorColor: themeSpec.cursorColor,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '查找',
                    hintStyle: TextStyle(color: themeSpec.mutedTextColor),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Text(
                resultText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: themeSpec.mutedTextColor,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                onPressed:
                    value.result == null ? null : controller.previousMatch,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                onPressed: value.result == null ? null : controller.nextMatch,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                onPressed: controller.close,
              ),
            ],
          ),
          if (value.replaceMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: TextField(
                      controller: controller.replaceInputController,
                      focusNode: controller.replaceInputFocusNode,
                      enabled: !readOnly,
                      style:
                          TextStyle(fontSize: 14, color: themeSpec.textColor),
                      cursorColor: themeSpec.cursorColor,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '替换为',
                        hintStyle: TextStyle(color: themeSpec.mutedTextColor),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: (value.result == null || readOnly)
                        ? null
                        : controller.replaceMatch,
                    child: const Text('替换'),
                  ),
                  TextButton(
                    onPressed: (value.result == null || readOnly)
                        ? null
                        : controller.replaceAllMatches,
                    child: const Text('全部'),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 40),
              _OptionChip(
                label: 'Aa',
                isSelected: value.option.caseSensitive,
                onPressed: controller.toggleCaseSensitive,
              ),
              const SizedBox(width: 8),
              _OptionChip(
                label: '.*',
                isSelected: value.option.regex,
                onPressed: controller.toggleRegex,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
