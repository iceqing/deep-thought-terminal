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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildIcon(colorScheme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitle(theme),
                ],
              ),
            ),
            if (item.isDirectory)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              )
            else
              Text(
                item.formattedDate,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: item.isDirectory 
            ? Colors.amber.withOpacity(0.1) 
            : _getFileIconColor(item).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        item.icon,
        size: 26,
        color: item.isDirectory ? Colors.amber[700] : _getFileIconColor(item),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    if (item.isDirectory) {
      return Text(
        '文件夹',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      );
    }

    return Row(
      children: [
        Text(
          item.formattedSize,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ),
        Text(
          _getFileExtension(item.name),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1 || lastDot == fileName.length - 1) return '文件';
    return fileName.substring(lastDot + 1).toUpperCase();
  }

  Color _getFileIconColor(FileItem item) {
    final ext = item.path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return Colors.green;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv'].contains(ext)) {
      return Colors.red;
    }
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma'].contains(ext)) {
      return Colors.purple;
    }
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return Colors.blue;
    }
    if (['dart', 'py', 'js', 'ts', 'java', 'c', 'cpp', 'h', 'go', 'rs'].contains(ext)) {
      return Colors.teal;
    }
    if (['zip', 'tar', 'gz', 'rar', '7z'].contains(ext)) {
      return Colors.orange;
    }
    return Colors.blueGrey;
  }
}

class FileGridItem extends StatelessWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FileGridItem({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 40,
                color: item.isDirectory ? Colors.amber[700] : _getFileIconColor(item),
              ),
              const SizedBox(height: 12),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.isDirectory ? '文件夹' : item.formattedSize,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFileIconColor(FileItem item) {
    // Reuse color logic from FileListTile
    final ext = item.path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Colors.green;
    if (['mp4', 'mkv', 'avi'].contains(ext)) return Colors.red;
    if (['mp3', 'wav', 'ogg'].contains(ext)) return Colors.purple;
    if (['pdf', 'doc', 'docx'].contains(ext)) return Colors.blue;
    if (['zip', 'tar', 'rar'].contains(ext)) return Colors.orange;
    return Colors.blueGrey;
  }
}
