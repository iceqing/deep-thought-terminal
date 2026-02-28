import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileListTile extends StatelessWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FileListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: item.isDirectory ? Colors.amber : _getFileIconColor(item),
      ),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: item.isDirectory
          ? null
          : Text(
              item.formattedSize,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: item.isDirectory
          ? const Icon(Icons.chevron_right, size: 20)
          : Text(
              item.formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Color _getFileIconColor(FileItem item) {
    final ext = item.path.split('.').last.toLowerCase();

    // Images - green
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return Colors.green;
    }
    // Videos - red
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv'].contains(ext)) {
      return Colors.red;
    }
    // Audio - purple
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma'].contains(ext)) {
      return Colors.purple;
    }
    // Documents - blue
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods'].contains(ext)) {
      return Colors.blue;
    }
    // Code - teal
    if (['dart', 'py', 'js', 'ts', 'java', 'c', 'cpp', 'h', 'go', 'rs', 'rb', 'php', 'swift', 'kt'].contains(ext)) {
      return Colors.teal;
    }
    // Archives - orange
    if (['zip', 'tar', 'gz', 'rar', '7z', 'bz2', 'xz'].contains(ext)) {
      return Colors.orange;
    }
    // Text - grey
    if (['txt', 'md', 'json', 'xml', 'yaml', 'yml', 'log', 'sh', 'bash', '', 'ini', 'html', 'conf', 'cfgcss'].contains(ext)) {
      return Colors.grey;
    }

    return Colors.grey;
  }
}
