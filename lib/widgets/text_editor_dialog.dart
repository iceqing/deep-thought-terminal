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
    _EditorThemeOption('atom', 'Atom One'),
    _EditorThemeOption('github', 'GitHub'),
    _EditorThemeOption('a11y', 'A11y'),
  ];

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
      setState(() {
        _showLineNumbers = showLines ?? true;
        _fontSize = (size ?? 14.0).clamp(10.0, 28.0);
        _wordWrap = wrap ?? true;
        _themeId = theme ?? 'auto';
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

  Future<void> _showEditorSettings() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('编辑器设置', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _themeId,
                      decoration: const InputDecoration(
                        labelText: '编辑器主题',
                      ),
                      items: _themeOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.id,
                              child: Text(option.label),
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('显示行号'),
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
                      value: _wordWrap,
                      onChanged: (value) {
                        setState(() => _wordWrap = value);
                        setSheetState(() {});
                        _saveEditorPreferences();
                      },
                    ),
                    Row(
                      children: [
                        const Text('字体大小'),
                        const SizedBox(width: 12),
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
                        SizedBox(
                          width: 38,
                          child: Text(
                            _fontSize.toStringAsFixed(0),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '支持双指缩放字体',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
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
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
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

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.fileName,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (!shouldPop || !mounted) return;
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '查找',
              onPressed: _findController.findMode,
            ),
            IconButton(
              icon: const Icon(Icons.find_replace),
              tooltip: '替换',
              onPressed: _findController.replaceMode,
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '编辑器设置',
              onPressed: _showEditorSettings,
            ),
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Modified',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _hasChanges && !_isSaving ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
        body: GestureDetector(
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
                    controller: controller, readOnly: readOnly);
              },
              wordWrap: _wordWrap,
              style: _buildEditorStyle(theme),
              indicatorBuilder: _showLineNumbers
                  ? (context, editingController, chunkController, notifier) {
                      return DefaultCodeLineNumber(
                        controller: editingController,
                        notifier: notifier,
                      );
                    }
                  : null,
              sperator: _showLineNumbers
                  ? Container(
                      width: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  CodeEditorStyle _buildEditorStyle(ThemeData theme) {
    return CodeEditorStyle(
      fontSize: _fontSize,
      fontFamily: 'JetBrainsMonoNerdFontMono',
      fontHeight: 1.55,
      backgroundColor: theme.colorScheme.surface,
      textColor: theme.colorScheme.onSurface,
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.16),
      cursorColor: theme.colorScheme.primary,
      codeTheme: _buildCodeTheme(theme.brightness),
    );
  }

  CodeHighlightTheme? _buildCodeTheme(Brightness brightness) {
    final language = _languageByFileName(widget.fileName);
    if (language == null) return null;

    final Map<String, TextStyle> palette;
    switch (_themeId) {
      case 'atom':
        palette = brightness == Brightness.dark
            ? atomOneDarkTheme
            : atomOneLightTheme;
        break;
      case 'github':
        palette = brightness == Brightness.dark ? githubDarkTheme : githubTheme;
        break;
      case 'a11y':
        palette =
            brightness == Brightness.dark ? a11YDarkTheme : a11YLightTheme;
        break;
      case 'auto':
      default:
        palette = brightness == Brightness.dark
            ? atomOneDarkTheme
            : atomOneLightTheme;
        break;
    }

    return CodeHighlightTheme(
      languages: {language.name: CodeHighlightThemeMode(mode: language.mode)},
      theme: palette,
    );
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

class _EditorFindPanel extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final bool readOnly;

  const _EditorFindPanel({
    required this.controller,
    required this.readOnly,
  });

  @override
  Size get preferredSize {
    final value = controller.value;
    if (value == null) return Size.zero;
    return Size.fromHeight(value.replaceMode ? 86 : 48);
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) {
      return const SizedBox.shrink();
    }

    final resultText = value.result == null
        ? '0/0'
        : '${value.result!.index + 1}/${value.result!.matches.length}';

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.findInputController,
                    focusNode: controller.findInputFocusNode,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '查找',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(resultText),
                IconButton(
                  tooltip: '上一个',
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed:
                      value.result == null ? null : controller.previousMatch,
                ),
                IconButton(
                  tooltip: '下一个',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: value.result == null ? null : controller.nextMatch,
                ),
                IconButton(
                  tooltip: '大小写',
                  icon: Text(
                    'Aa',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: value.option.caseSensitive
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  onPressed: controller.toggleCaseSensitive,
                ),
                IconButton(
                  tooltip: '正则',
                  icon: Text(
                    '.*',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: value.option.regex
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  onPressed: controller.toggleRegex,
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: controller.close,
                ),
              ],
            ),
            if (value.replaceMode)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.replaceInputController,
                      focusNode: controller.replaceInputFocusNode,
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '替换为',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (value.result == null || readOnly)
                        ? null
                        : controller.replaceMatch,
                    child: const Text('替换'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: (value.result == null || readOnly)
                        ? null
                        : controller.replaceAllMatches,
                    child: const Text('全部替换'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
