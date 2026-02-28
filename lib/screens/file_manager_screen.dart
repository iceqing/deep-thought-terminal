import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/text_editor_dialog.dart';
import '../l10n/app_localizations.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  static const Set<String> _externalOnlyExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'flv',
    'wmv',
    'mp3',
    'wav',
    'ogg',
    'flac',
    'aac',
    'm4a',
    'wma',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'zip',
    'tar',
    'gz',
    'rar',
    '7z',
    'bz2',
    'xz',
    'apk',
    'aab',
    'so',
    'bin',
    'exe',
    'dll',
    'class',
    'jar',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FileManagerProvider>();
      if (!provider.initialized) {
        provider.init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fileManagerProvider = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fileManager),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showCreateFolderDialog(context),
            tooltip: '新建文件夹',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FileManagerProvider>().refresh(),
            tooltip: l10n.refresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    const Icon(Icons.home),
                    const SizedBox(width: 12),
                    Text(l10n.home),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'storage',
                child: Row(
                  children: [
                    const Icon(Icons.storage),
                    const SizedBox(width: 12),
                    Text(l10n.storageDirectories),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history_back',
                enabled: fileManagerProvider.canGoBack,
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 12),
                    const Text('返回上一次位置'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_hidden',
                child: Row(
                  children: [
                    const Icon(Icons.visibility),
                    const SizedBox(width: 12),
                    Text(
                      fileManagerProvider.showHiddenFiles
                          ? '关闭隐藏文件显示'
                          : '显示隐藏文件',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_current_folder',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 12),
                    Text('打开当前文件夹'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<FileManagerProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildPathBar(context, provider, l10n),
              Expanded(child: _buildContent(context, provider, l10n)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPathBar(
    BuildContext context,
    FileManagerProvider provider,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            onPressed:
                provider.canGoParent ? () => provider.navigateToParent() : null,
            tooltip: '上一级',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showPathDialog(context, provider),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前目录',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    provider.currentPath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FileManagerProvider provider,
    AppLocalizations l10n,
  ) {
    if (provider.isLoading && provider.fileList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.fileList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (provider.fileList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.emptyDirectory,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: provider.fileList.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
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

  void _handleFileTap(
      BuildContext context, dynamic provider, dynamic item) async {
    if (item.isDirectory) {
      await provider.navigateTo(item.path);
    } else {
      if (_shouldOpenExternally(item)) {
        _openExternally(context, provider, item);
      } else {
        await _openTextEditor(context, provider, item);
      }
    }
  }

  bool _shouldOpenExternally(dynamic item) {
    final lowerName = item.name.toString().toLowerCase();
    final dotIndex = lowerName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == lowerName.length - 1) {
      return false;
    }
    final ext = lowerName.substring(dotIndex + 1);
    return _externalOnlyExtensions.contains(ext);
  }

  Future<bool> _openTextEditor(
    BuildContext context,
    dynamic provider,
    dynamic item,
  ) async {
    try {
      final content = await provider.getFileContent(item.path);
      if (!mounted) return false;

      await TextEditorDialog.show(
        context,
        fileName: item.name,
        initialContent: content,
        onSave: (newContent) async {
          await provider.saveFileContent(item.path, newContent);
        },
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
      return false;
    }
  }

  void _openExternally(
      BuildContext context, dynamic provider, dynamic item) async {
    try {
      await provider.openFileExternally(item.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
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
          ),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(dialogContext);
            try {
              await provider.createFolder(name);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('文件夹已创建: $name')),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('创建失败: $e')),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await provider.createFolder(name);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('文件夹已创建: $name')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('创建失败: $e')),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showFileOptions(BuildContext context, dynamic provider, dynamic item) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(item.isDirectory ? Icons.folder_open : item.icon),
              title: Text(item.name),
              subtitle: item.isDirectory ? null : Text(item.formattedSize),
            ),
            const Divider(),
            if (!item.isDirectory && item.isTextFile) ...[
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('查看/编辑文本'),
                onTap: () {
                  Navigator.pop(context);
                  _openTextEditor(context, provider, item);
                },
              ),
            ],
            if (!item.isDirectory) ...[
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.openFile),
                onTap: () {
                  Navigator.pop(context);
                  _openExternally(context, provider, item);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.fileInfo),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(context, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context, dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(item.icon),
            const SizedBox(width: 12),
            Expanded(child: Text(item.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Path', item.path),
            _infoRow('Type', item.isDirectory ? 'Directory' : 'File'),
            if (!item.isDirectory) _infoRow('Size', item.formattedSize),
            _infoRow('Modified', item.modifiedDate.toString()),
            if (item.permissions.isNotEmpty)
              _infoRow('Permissions', item.permissions),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
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
        if (!mounted || !granted) return;
        _showStorageDirectories(context, provider);
        break;
      case 'history_back':
        if (provider.canGoBack) {
          await provider.goBack();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可返回的历史位置')),
          );
        }
        break;
      case 'toggle_hidden':
        await provider.setShowHiddenFiles(!provider.showHiddenFiles);
        break;
      case 'open_current_folder':
        try {
          await provider.openCurrentDirectoryExternally();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打开失败: $e')),
          );
        }
        break;
    }
  }

  Future<bool> _ensureStoragePermission(
      BuildContext context, FileManagerProvider provider) async {
    await provider.checkStoragePermission();
    if (provider.hasStoragePermission) return true;
    if (!mounted) return false;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text('访问共享存储目录需要授权，是否现在去授权？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;
    final granted = await provider.requestStoragePermission();
    if (!mounted) return granted;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获得存储权限，将仅显示应用可访问目录')),
      );
    }
    return granted;
  }

  void _showStorageDirectories(BuildContext context, dynamic provider) async {
    try {
      final dirs = await provider.getStorageDirectories();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).storageDirectories,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...dirs.map((dir) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(dir),
                    onTap: () {
                      Navigator.pop(context);
                      provider.navigateTo(dir);
                    },
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showPathDialog(BuildContext context, dynamic provider) {
    final controller = TextEditingController(text: provider.currentPath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter directory path',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              provider.navigateTo(controller.text);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}
