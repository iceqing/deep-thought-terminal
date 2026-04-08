import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen text viewer for terminal output.
/// Converts the terminal buffer into a scrollable, selectable text view.
class TerminalTextViewer extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onClose;

  const TerminalTextViewer({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
        title: Text(
          'Terminal Output',
          style: TextStyle(color: foregroundColor, fontSize: 16),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy all',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied all text'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_bottom),
            tooltip: 'Scroll to bottom',
            onPressed: () {
              // Will be handled by the scroll controller
              _scrollKey.currentState?.scrollToBottom();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _TextContent(
        key: _scrollKey,
        text: text,
        fontFamily: fontFamily,
        fontSize: fontSize,
        foregroundColor: foregroundColor,
      ),
    );
  }

  static final _scrollKey = GlobalKey<_TextContentState>();
}

class _TextContent extends StatefulWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color foregroundColor;

  const _TextContent({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.foregroundColor,
  });

  @override
  State<_TextContent> createState() => _TextContentState();
}

class _TextContentState extends State<_TextContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          widget.text,
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontSize: widget.fontSize,
            color: widget.foregroundColor,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
