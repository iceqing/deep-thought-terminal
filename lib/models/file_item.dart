import 'package:flutter/material.dart';

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedDate;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    required this.modifiedDate,
    this.permissions = '',
  });

  IconData get icon {
    if (isDirectory) return Icons.folder;

    final ext = path.split('.').last.toLowerCase();

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return Icons.image;
    }
    // Videos
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv'].contains(ext)) {
      return Icons.video_file;
    }
    // Audio
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma'].contains(ext)) {
      return Icons.audio_file;
    }
    // Documents
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods'].contains(ext)) {
      return Icons.description;
    }
    // Code
    if (['dart', 'py', 'js', 'ts', 'java', 'c', 'cpp', 'h', 'go', 'rs', 'rb', 'php', 'swift', 'kt'].contains(ext)) {
      return Icons.code;
    }
    // Archives
    if (['zip', 'tar', 'gz', 'rar', '7z', 'bz2', 'xz'].contains(ext)) {
      return Icons.archive;
    }
    // Text
    if (['txt', 'md', 'json', 'xml', 'yaml', 'yml', 'log', 'sh', 'bash', 'conf', 'cfg', 'ini', 'html', 'css'].contains(ext)) {
      return Icons.text_snippet;
    }

    return Icons.insert_drive_file;
  }

  bool get isTextFile {
    if (isDirectory) return false;

    final ext = path.split('.').last.toLowerCase();
    const textExtensions = [
      'txt', 'md', 'json', 'xml', 'yaml', 'yml', 'log', 'sh', 'bash',
      'conf', 'cfg', 'ini', 'html', 'css', 'js', 'ts', 'dart', 'py',
      'java', 'c', 'cpp', 'h', 'go', 'rs', 'rb', 'php', 'swift', 'kt',
      'sql', 'gitignore', 'env', 'properties', 'gradle', 'toml'
    ];
    return textExtensions.contains(ext);
  }

  String get formattedSize {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(modifiedDate);

    if (diff.inDays == 0) {
      return '${modifiedDate.hour.toString().padLeft(2, '0')}:${modifiedDate.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${modifiedDate.year}-${modifiedDate.month.toString().padLeft(2, '0')}-${modifiedDate.day.toString().padLeft(2, '0')}';
    }
  }
}
