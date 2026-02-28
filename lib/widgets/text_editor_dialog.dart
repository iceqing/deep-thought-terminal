import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextEditorDialog extends StatefulWidget {
  final String fileName;
  final String initialContent;
  final Function(String) onSave;

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
    required Function(String) onSave,
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

  late TextEditingController _controller;
  late ScrollController _editorScrollController;
  late ScrollController _lineNumberScrollController;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _showLineNumbers = true;
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _editorScrollController = ScrollController()
      ..addListener(_syncLineNumberScroll);
    _lineNumberScrollController = ScrollController();
    _controller.addListener(_onTextChanged);
    _loadEditorPreferences();
  }

  void _onTextChanged() {
    final hasChanges = _controller.text != widget.initialContent;
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _editorScrollController.removeListener(_syncLineNumberScroll);
    _editorScrollController.dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  int get _lineCount {
    final text = _controller.text;
    if (text.isEmpty) return 1;
    return '\n'.allMatches(text).length + 1;
  }

  Future<void> _loadEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showLines = prefs.getBool(_prefShowLineNumbers);
      final size = prefs.getDouble(_prefFontSize);
      if (!mounted) return;
      setState(() {
        _showLineNumbers = showLines ?? true;
        _fontSize = (size ?? 14.0).clamp(10.0, 28.0);
      });
    } catch (_) {
      // Ignore preference load failures and use defaults.
    }
  }

  Future<void> _saveEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefShowLineNumbers, _showLineNumbers);
      await prefs.setDouble(_prefFontSize, _fontSize);
    } catch (_) {
      // Ignore preference save failures.
    }
  }

  void _syncLineNumberScroll() {
    if (!_lineNumberScrollController.hasClients) return;
    final max = _lineNumberScrollController.position.maxScrollExtent;
    final target = _editorScrollController.offset.clamp(0.0, max);
    if ((_lineNumberScrollController.offset - target).abs() > 0.5) {
      _lineNumberScrollController.jumpTo(target);
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
      await widget.onSave(_controller.text);
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
        body: Padding(
          padding: EdgeInsets.zero,
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showLineNumbers)
                  Container(
                    width: 56,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    child: SingleChildScrollView(
                      controller: _lineNumberScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(_lineCount, (index) {
                          return Text(
                            '${index + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: _fontSize,
                              height: 1.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    scrollController: _editorScrollController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: _fontSize,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      hintText: 'Enter file content...',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
