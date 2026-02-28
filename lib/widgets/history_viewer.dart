import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';

/// 历史记录查看器
/// 优化的交互体验：点击复制并关闭，长按显示更多选项
class HistoryViewer extends StatefulWidget {
  /// 选中命令的回调（用于直接发送到终端）
  final void Function(String command)? onCommandSelected;

  const HistoryViewer({super.key, this.onCommandSelected});

  /// 显示历史查看器
  static Future<String?> show(BuildContext context, {
    void Function(String command)? onCommandSelected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HistoryViewer(onCommandSelected: onCommandSelected),
    );
  }

  @override
  State<HistoryViewer> createState() => _HistoryViewerState();
}

class _HistoryViewerState extends State<HistoryViewer> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _historyService = HistoryService();
  List<HistoryEntry> _entries = [];
  List<HistoryEntry> _filteredEntries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      List<HistoryEntry> entries;

      if (authProvider.isLoggedIn) {
        // 已登录：从后端 API 获取历史记录
        final apiData = await ApiService.getHistory(limit: 500);
        entries = apiData.asMap().entries.map((e) {
          final item = e.value;
          DateTime? timestamp;
          if (item['created_at'] != null) {
            timestamp = DateTime.tryParse(item['created_at']);
          } else if (item['timestamp'] != null) {
            timestamp = DateTime.tryParse(item['timestamp'].toString());
          }
          return HistoryEntry(
            index: e.key + 1,
            command: item['command'] ?? '',
            timestamp: timestamp,
          );
        }).toList();
      } else {
        // 游客模式：从本地文件读取
        entries = await _historyService.getAllHistory();
      }

      // 最新的在前
      entries.sort((a, b) => b.index.compareTo(a.index));
      if (mounted) {
        setState(() {
          _entries = entries;
          _filteredEntries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _filterHistory() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredEntries = _entries);
    } else {
      setState(() {
        _filteredEntries = _entries
            .where((e) => e.command.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  void _copyCommand(String command, {bool closeAfter = true}) {
    Clipboard.setData(ClipboardData(text: command));
    HapticFeedback.lightImpact();

    if (closeAfter) {
      Navigator.pop(context, command);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Copied: $command',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command copied'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCommandOptions(HistoryEntry entry) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.command,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy command'),
              onTap: () {
                Navigator.pop(context);
                _copyCommand(entry.command, closeAfter: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_go),
              title: const Text('Copy and close'),
              subtitle: const Text('Copy command and close history'),
              onTap: () {
                Navigator.pop(context);
                _copyCommand(entry.command, closeAfter: true);
              },
            ),
            if (widget.onCommandSelected != null)
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Execute command'),
                subtitle: const Text('Send to terminal'),
                onTap: () {
                  Navigator.pop(context); // 关闭选项菜单
                  Navigator.pop(context); // 关闭历史查看器
                  widget.onCommandSelected!(entry.command);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Command History',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_filteredEntries.length} commands',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadHistory,
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              // 搜索框
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search commands...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // 提示信息
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to copy',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.touch_app, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Long press for options',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 历史列表
              Expanded(
                child: _buildContent(scrollController, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController, bool isDark) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading history...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading history', style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.history_toggle_off
                  : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No history yet'
                  : 'No matching commands',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Commands will appear here',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filteredEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        return _HistoryEntryTile(
          entry: entry,
          query: _searchController.text,
          isDark: isDark,
          onTap: () => _copyCommand(entry.command),
          onLongPress: () => _showCommandOptions(entry),
        );
      },
    );
  }
}

/// 历史记录条目 Tile
class _HistoryEntryTile extends StatelessWidget {
  final HistoryEntry entry;
  final String query;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryEntryTile({
    required this.entry,
    required this.query,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 序号
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.index}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 命令内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlightedText(entry.command, query, context),
                  if (entry.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(entry.timestamp!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 复制图标
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );

    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withOpacity(0.4),
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ));

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 365) {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    } else if (diff.inDays > 7) {
      return '${timestamp.month}/${timestamp.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} min ago';
    } else {
      return 'just now';
    }
  }
}
