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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fileManager),
        actions: [
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
            ],
          ),
        ],
      ),
      body: Consumer<FileManagerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.fileList.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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

          return Column(
            children: [
              // Breadcrumb / Path bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    if (provider.canGoBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: () => provider.goBack(),
                        tooltip: l10n.back,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (provider.canGoBack) const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showPathDialog(context, provider),
                        child: Text(
                          provider.currentPath,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // File list
              Expanded(
                child: ListView.separated(
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleFileTap(BuildContext context, dynamic provider, dynamic item) async {
    if (item.isDirectory) {
      await provider.navigateTo(item.path);
    } else {
      // Open file based on type
      if (item.isTextFile) {
        _openTextEditor(context, provider, item);
      } else {
        _openExternally(context, provider, item);
      }
    }
  }

  void _openTextEditor(BuildContext context, dynamic provider, dynamic item) async {
    try {
      final content = await provider.getFileContent(item.path);
      if (!mounted) return;

      await TextEditorDialog.show(
        context,
        fileName: item.name,
        initialContent: content,
        onSave: (newContent) async {
          await provider.saveFileContent(item.path, newContent);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  void _openExternally(BuildContext context, dynamic provider, dynamic item) async {
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
            if (!item.isDirectory) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.editFile),
                onTap: () {
                  Navigator.pop(context);
                  _openTextEditor(context, provider, item);
                },
              ),
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
            if (item.permissions.isNotEmpty) _infoRow('Permissions', item.permissions),
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
        final homeDir = provider.currentPath.startsWith('/storage')
            ? '/storage/emulated/0'
            : provider.currentPath.split('/').take(3).join('/');
        if (homeDir.isNotEmpty && homeDir != provider.currentPath) {
          await provider.navigateTo(homeDir);
        }
        break;
      case 'storage':
        _showStorageDirectories(context, provider);
        break;
    }
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
