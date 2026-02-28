import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FileService {
  /// Get the initial directory to start browsing from
  Future<String> getInitialDirectory() async {
    if (Platform.isAndroid) {
      final directories = await getExternalStorageDirectories();
      if (directories != null && directories.isNotEmpty) {
        // Navigate up to a reasonable starting point
        String path = directories.first.path;
        // Go up from Android/data/... to a more usable location
        final segments = path.split('/');
        final index = segments.indexOf('Android');
        if (index > 0) {
          path = segments.sublist(0, index).join('/');
        }
        return path;
      }
      return (await getApplicationDocumentsDirectory()).path;
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return Platform.environment['HOME'] ?? (await getApplicationDocumentsDirectory()).path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// List files and directories in a given path
  Future<List<FileSystemEntity>> listDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $path');
    }
    return directory.listSync();
  }

  /// Get file items from a directory path
  Future<List<dynamic>> getFileItems(String path) async {
    final entities = await listDirectory(path);
    final items = <dynamic>[];

    for (final entity in entities) {
      try {
        final stat = await entity.stat();
        final name = p.basename(entity.path);

        // Skip hidden files (starting with .)
        if (name.startsWith('.')) continue;

        items.add({
          'name': name,
          'path': entity.path,
          'isDirectory': entity is Directory,
          'size': stat.size,
          'modifiedDate': stat.modified,
          'permissions': _getPermissionString(stat.mode),
        });
      } catch (e) {
        // Skip files we can't access
        continue;
      }
    }

    // Sort: directories first, then files, alphabetically
    items.sort((a, b) {
      if (a['isDirectory'] && !b['isDirectory']) return -1;
      if (!a['isDirectory'] && b['isDirectory']) return 1;
      return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
    });

    return items;
  }

  String _getPermissionString(int mode) {
    String result = '';
    result += (mode & 0x100) != 0 ? 'r' : '-';
    result += (mode & 0x80) != 0 ? 'w' : '-';
    result += (mode & 0x40) != 0 ? 'x' : '-';
    result += (mode & 0x20) != 0 ? 'r' : '-';
    result += (mode & 0x10) != 0 ? 'w' : '-';
    result += (mode & 0x8) != 0 ? 'x' : '-';
    result += (mode & 0x4) != 0 ? 'r' : '-';
    result += (mode & 0x2) != 0 ? 'w' : '-';
    result += (mode & 0x1) != 0 ? 'x' : '-';
    return result;
  }

  /// Get parent directory path
  String getParentDirectory(String path) {
    return p.dirname(path);
  }

  /// Check if path is root
  bool isRoot(String path) {
    if (Platform.isAndroid) {
      return path == '/';
    }
    return path == '/';
  }

  /// Read file content as string
  Future<String> getFileContent(String path, {int maxSize = 1024 * 1024}) async {
    final file = File(path);
    final stat = await file.stat();

    if (stat.size > maxSize) {
      throw Exception('File is too large (${stat.size} bytes). Maximum allowed: $maxSize bytes.');
    }

    return file.readAsString();
  }

  /// Save file content
  Future<void> saveFileContent(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Open file with external application
  Future<void> openFileExternally(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File does not exist: $path');
    }

    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Cannot open file: $path');
    }
  }

  /// Get available storage directories
  Future<List<String>> getStorageDirectories() async {
    final directories = <String>[];

    if (Platform.isAndroid) {
      // Get external storage
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          // Navigate up to find usable root
          String path = dir.path;
          final segments = path.split('/');
          final androidIndex = segments.indexOf('Android');
          if (androidIndex > 0) {
            path = segments.sublist(0, androidIndex).join('/');
          }
          if (!directories.contains(path)) {
            directories.add(path);
          }
        }
      }

      // Add common Android directories
      directories.add('/storage/emulated/0');
      directories.add('/sdcard');
    } else {
      directories.add(Platform.environment['HOME'] ?? '/home');
      directories.add('/');
    }

    return directories;
  }

  /// Check if file exists
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Check if directory exists
  Future<bool> directoryExists(String path) async {
    return Directory(path).exists();
  }
}
