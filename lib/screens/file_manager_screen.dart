import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/text_editor_dialog.dart';
import '../l10n/app_localizations.dart';
import '../models/file_item.dart';

class FileManagerScreen extends StatefulWidget {
  final String? initialPath;

  const FileManagerScreen({super.key, this.initialPath});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  static const Set<String> _externalOnlyExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv',
    'mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
    'zip', 'tar', 'gz', 'rar', '7z', 'bz2', 'xz',
    'apk', 'aab', 'so', 'bin', 'exe', 'dll', 'class', 'jar',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FileManagerProvider>();
      if (!provider.initialized) {
        provider.init(initialPath: widget.initialPath);
        return;
      }

      final initialPath = widget.initialPath;
      if (initialPath != null &&
          initialPath.isNotEmpty &&
          provider.currentPath != initialPath) {
        provider.navigateTo(initialPath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<FileManagerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.fileManager),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: Icon(provider.isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => provider.toggleViewMode(),
            tooltip: '切换视图',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => provider.setSortBy(value),
            itemBuilder: (context) => [
              _buildSortItem('name', '按名称', provider),
              _buildSortItem('date', '按日期', provider),
              _buildSortItem('size', '按大小', provider),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              _buildMenuItem('home', Icons.home_outlined, l10n.home),
              _buildMenuItem('storage', Icons.storage_outlined, l10n.storageDirectories),
              _buildMenuItem('history_back', Icons.history, '返回上一次位置', enabled: provider.canGoBack),
              _buildMenuItem('toggle_hidden', Icons.visibility_outlined, 
                  provider.showHiddenFiles ? '关闭隐藏文件' : '显示隐藏文件'),
              _buildMenuItem('open_current_folder', Icons.open_in_new, '在系统打开'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(context, provider),
          Expanded(
            child: provider.isLoading && provider.fileList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => provider.refresh(),
                    child: _buildContent(context, provider, l10n),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFolderDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新建文件夹'),
        elevation: 2,
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, FileManagerProvider provider) {
    final isSelected = provider.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected 
                ? (provider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : null,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          )),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label, {bool enabled = true}) {
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, FileManagerProvider provider) {
    final path = provider.currentPath;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    final List<String> absolutePaths = [];
    String current = '';
    for (var part in parts) {
      current += '/$part';
      absolutePaths.add(current);
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length + 1,
        separatorBuilder: (context, index) => Icon(
          Icons.chevron_right, 
          size: 16, 
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)
        ),
        itemBuilder: (context, index) {
          final isLast = index == parts.length;
          final String label = index == 0 ? '根目录' : parts[index - 1];
          final String targetPath = index == 0 ? '/' : absolutePaths[index - 1];

          return InkWell(
            onTap: isLast ? null : () => provider.navigateTo(targetPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isLast 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, FileManagerProvider provider, AppLocalizations l10n) {
    if (provider.error != null && provider.fileList.isEmpty) {
      return _buildErrorState(context, provider, l10n);
    }

    if (provider.fileList.isEmpty) {
      return _buildEmptyState(context, l10n);
    }

    if (provider.isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: provider.fileList.length,
        itemBuilder: (context, index) {
          final item = provider.fileList[index];
          return FileGridItem(
            item: item,
            onTap: () => _handleFileTap(context, provider, item),
            onLongPress: () => _showFileOptions(context, provider, item),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: provider.fileList.length,
      itemBuilder: (context, index) {
        final item = provider.fileList[index];
        return FileListTile(
          item: item,
          onTap: () => _handleFileTap(context, provider, item),
          onLongPress: () => _showFileOptions(context, provider, item),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.emptyDirectory,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, FileManagerProvider provider, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('出错了', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFileTap(BuildContext context, FileManagerProvider provider, FileItem item) async {
    if (item.isDirectory) {
      await provider.navigateTo(item.path);
    } else {
      if (_shouldOpenExternally(item)) {
        if (!context.mounted) return;
        _openExternally(context, provider, item);
      } else {
        if (!context.mounted) return;
        await _openTextEditor(context, provider, item);
      }
    }
  }

  bool _shouldOpenExternally(FileItem item) {
    final lowerName = item.name.toLowerCase();
    final dotIndex = lowerName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == lowerName.length - 1) return false;
    final ext = lowerName.substring(dotIndex + 1);
    return _externalOnlyExtensions.contains(ext);
  }

  Future<void> _openTextEditor(BuildContext context, FileManagerProvider provider, FileItem item) async {
    try {
      final content = await provider.getFileContent(item.path);
      if (!context.mounted) return;

      await TextEditorDialog.show(
        context,
        fileName: item.name,
        initialContent: content,
        onSave: (newContent) async {
          await provider.saveFileContent(item.path, newContent);
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开文件失败: $e')));
      }
    }
  }

  void _openExternally(BuildContext context, FileManagerProvider provider, FileItem item) async {
    try {
      await provider.openFileExternally(item.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败: $e')));
      }
    }
  }

  void _showCreateFolderDialog(BuildContext context) {
    final provider = context.read<FileManagerProvider>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => _performCreateFolder(context, provider, value, dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _performCreateFolder(context, provider, controller.text, dialogContext),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _performCreateFolder(BuildContext context, FileManagerProvider provider, String name, BuildContext dialogContext) async {
    final folderName = name.trim();
    if (folderName.isEmpty) return;
    Navigator.pop(dialogContext);
    try {
      await provider.createFolder(folderName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件夹 "$folderName" 已创建')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  void _showFileOptions(BuildContext context, FileManagerProvider provider, FileItem item) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                        if (!item.isDirectory)
                          Text(item.formattedSize, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!item.isDirectory && item.isTextFile)
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('编辑文本'),
                onTap: () {
                  Navigator.pop(context);
                  _openTextEditor(context, provider, item);
                },
              ),
            if (!item.isDirectory)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.openFile),
                onTap: () {
                  Navigator.pop(context);
                  _openExternally(context, provider, item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.fileInfo),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(context, item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context, FileItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('名称', item.name),
            _infoRow('路径', item.path),
            _infoRow('类型', item.isDirectory ? '文件夹' : '文件'),
            if (!item.isDirectory) _infoRow('大小', item.formattedSize),
            _infoRow('修改日期', item.modifiedDate.toString()),
            if (item.permissions.isNotEmpty)
              _infoRow('权限', item.permissions),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    final provider = context.read<FileManagerProvider>();

    switch (action) {
      case 'home':
        await provider.navigateHome();
        break;
      case 'storage':
        final granted = await _ensureStoragePermission(context, provider);
        if (!context.mounted || !granted) return;
        _showStorageDirectories(context, provider);
        break;
      case 'history_back':
        if (provider.canGoBack) await provider.goBack();
        break;
      case 'toggle_hidden':
        await provider.setShowHiddenFiles(!provider.showHiddenFiles);
        break;
      case 'open_current_folder':
        try {
          await provider.openCurrentDirectoryExternally();
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败: $e')));
        }
        break;
    }
  }

  Future<bool> _ensureStoragePermission(BuildContext context, FileManagerProvider provider) async {
    await provider.checkStoragePermission();
    if (provider.hasStoragePermission) return true;
    if (!context.mounted) return false;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text('访问共享存储目录需要授权，是否现在去授权？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('去授权')),
        ],
      ),
    );

    if (shouldRequest != true) return false;
    return await provider.requestStoragePermission();
  }

  void _showStorageDirectories(BuildContext context, FileManagerProvider provider) async {
    try {
      final dirs = await provider.getStorageDirectories();
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('存储目录', style: Theme.of(context).textTheme.titleMedium),
              ),
              ...dirs.map((dir) => ListTile(
                leading: const Icon(Icons.storage),
                title: Text(dir),
                onTap: () {
                  Navigator.pop(context);
                  provider.navigateTo(dir);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取目录失败: $e')));
    }
  }
}
