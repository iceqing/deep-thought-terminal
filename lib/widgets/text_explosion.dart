import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Big Bang" text explosion overlay for easy text selection on mobile.
/// Long-press on terminal → extract visible text → show tokenized chips
/// that users can tap to select/deselect, then copy.
class TextExplosionOverlay extends StatefulWidget {
  final String text;
  final String fontFamily;
  final Color backgroundColor;
  final Color foregroundColor;

  const TextExplosionOverlay({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  /// Show the text explosion as a full-screen modal route.
  /// Returns the selected text if user chose "Paste to terminal", null otherwise.
  static Future<String?> show(
    BuildContext context, {
    required String text,
    required String fontFamily,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    if (text.trim().isEmpty) return Future.value(null);

    return Navigator.of(context).push<String?>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return TextExplosionOverlay(
            text: text,
            fontFamily: fontFamily,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  State<TextExplosionOverlay> createState() => _TextExplosionOverlayState();
}

class _TextExplosionOverlayState extends State<TextExplosionOverlay> {
  late List<_Token> _tokens;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _tokens = _tokenize(widget.text);
  }

  /// Tokenize text into words and separators.
  /// Keeps line structure by inserting line-break tokens.
  List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    final lines = text.split('\n');

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li].trimRight();
      if (line.isEmpty) {
        if (li < lines.length - 1) {
          tokens.add(_Token('\n', isLineBreak: true));
        }
        continue;
      }

      // Split line into words by whitespace, keeping meaningful tokens
      final words = _splitLine(line);
      for (final word in words) {
        if (word.trim().isNotEmpty) {
          tokens.add(_Token(word));
        }
      }

      if (li < lines.length - 1) {
        tokens.add(_Token('\n', isLineBreak: true));
      }
    }

    return tokens;
  }

  /// Split a line into tokens: words, paths, IPs, URLs, punctuation groups.
  List<String> _splitLine(String line) {
    final tokens = <String>[];
    // Match: paths (/foo/bar), URLs, IPs, words, or punctuation clusters
    final regex = RegExp(
      r'''(?:[a-zA-Z]+://\S+)'''       // URLs
      r'''|(?:[~/.]?(?:/[\w\-.@]+)+)''' // Unix paths
      r'''|(?:\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?)''' // IP addresses
      r'''|(?:[\w\-.@:]+)'''           // Words (including user@host, key:value)
      r'''|(?:[^\s\w]+)''',            // Punctuation clusters
    );

    for (final match in regex.allMatches(line)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  String get _selectedText {
    final selected = <String>[];
    for (int i = 0; i < _tokens.length; i++) {
      if (_selectedIndices.contains(i)) {
        selected.add(_tokens[i].text);
      }
    }
    return selected.join(' ');
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < _tokens.length; i++) {
        if (!_tokens[i].isLineBreak) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIndices.clear());
  }

  void _copyAndClose() {
    final text = _selectedText;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      Navigator.pop(context); // don't return text — just copy to clipboard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _pasteToTerminal() {
    final text = _selectedText;
    if (text.isNotEmpty) {
      Navigator.pop(context, text); // return text to paste into terminal
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedIndices.isNotEmpty;

    return Scaffold(
      backgroundColor: widget.backgroundColor.withValues(alpha: 0.97),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: widget.foregroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          hasSelection
              ? '${_selectedIndices.length} selected'
              : 'Tap to select',
          style: TextStyle(
            color: widget.foregroundColor.withValues(alpha: 0.8),
            fontSize: 16,
          ),
        ),
        centerTitle: false,
        actions: [
          if (hasSelection) ...[
            IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: _clearSelection,
              tooltip: 'Clear',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: 'Select All',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Token chips area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: _buildTokenChips(),
              ),
            ),
          ),

          // Preview & action bar
          if (hasSelection)
            _buildActionBar(theme),
        ],
      ),
    );
  }

  List<Widget> _buildTokenChips() {
    final chips = <Widget>[];

    for (int i = 0; i < _tokens.length; i++) {
      final token = _tokens[i];

      if (token.isLineBreak) {
        // Line break indicator — full width
        chips.add(SizedBox(
          width: double.infinity,
          height: 6,
          child: Center(
            child: Container(
              height: 1,
              color: widget.foregroundColor.withValues(alpha: 0.08),
            ),
          ),
        ));
        continue;
      }

      final isSelected = _selectedIndices.contains(i);
      chips.add(_TokenChip(
        text: token.text,
        isSelected: isSelected,
        foregroundColor: widget.foregroundColor,
        fontFamily: widget.fontFamily,
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIndices.remove(i);
            } else {
              _selectedIndices.add(i);
            }
          });
        },
      ));
    }

    return chips;
  }

  Widget _buildActionBar(ThemeData theme) {
    final previewText = _selectedText;
    return Container(
      decoration: BoxDecoration(
        color: widget.foregroundColor.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(
            color: widget.foregroundColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            if (previewText.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  previewText,
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 13,
                    color: widget.foregroundColor.withValues(alpha: 0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _copyAndClose,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pasteToTerminal,
                      icon: const Icon(Icons.terminal, size: 18),
                      label: const Text('Paste to terminal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.foregroundColor,
                        side: BorderSide(
                          color: widget.foregroundColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Token {
  final String text;
  final bool isLineBreak;

  _Token(this.text, {this.isLineBreak = false});
}

class _TokenChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final Color foregroundColor;
  final String fontFamily;
  final VoidCallback onTap;

  const _TokenChip({
    required this.text,
    required this.isSelected,
    required this.foregroundColor,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
              : foregroundColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                : foregroundColor.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : foregroundColor.withValues(alpha: 0.85),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
