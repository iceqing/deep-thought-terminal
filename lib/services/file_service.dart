import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'storage_service.dart';
import '../utils/constants.dart';

class FileService {
  /// Get the initial directory to start browsing from
  Future<String> getInitialDirectory() async {
    if (Platform.isAndroid) {
      final home = await getHomeDirectory();
      if (home.isNotEmpty) {
        return home;
      }
      return await _getAppDocumentsPath();
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final home = Platform.environment['HOME'];
      if (home != null && await _isReadableDirectory(home)) {
        return home;
      }
      return await _getAppDocumentsPath();
    }
    return await _getAppDocumentsPath();
  }

  /// Get a safe "home" directory for the file manager.
  Future<String> getHomeDirectory() async {
    if (Platform.isAndroid) {
      // 默认进入终端所在的 HOME 目录。
      final termuxHome = TermuxConstants.homeDir;
      if (await _isReadableDirectory(termuxHome)) {
        return termuxHome;
      }

      // 回退到 app 专属目录。
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          if (await _isReadableDirectory(dir.path)) {
            return dir.path;
          }
        }
      }

      return await _getAppDocumentsPath();
    }

    final home = Platform.environment['HOME'];
    if (home != null && await _isReadableDirectory(home)) {
      return home;
    }
    return await _getAppDocumentsPath();
  }

  /// List files and directories in a given path
  Future<List<FileSystemEntity>> listDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $path');
    }
    try {
      return await directory.list(followLinks: false).toList();
    } on FileSystemException catch (e) {
      throw Exception(
          'Directory listing failed: $path (${e.osError?.message ?? e.message})');
    }
  }

  /// Get file items from a directory path
  Future<List<dynamic>> getFileItems(
    String path, {
    bool includeHidden = false,
  }) async {
    final entities = await listDirectory(path);
    final items = <dynamic>[];

    for (final entity in entities) {
      try {
        final stat = await entity.stat();
        final name = p.basename(entity.path);
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: true,
        );
        final isDirectory = type == FileSystemEntityType.directory;

        // Skip hidden files unless explicitly included.
        if (!includeHidden && name.startsWith('.')) continue;

        items.add({
          'name': name,
          'path': entity.path,
          'isDirectory': isDirectory,
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
  Future<String> getFileContent(String path,
      {int maxSize = 1024 * 1024}) async {
    final file = File(path);
    final stat = await file.stat();

    if (stat.size > maxSize) {
      throw Exception(
          'File is too large (${stat.size} bytes). Maximum allowed: $maxSize bytes.');
    }

    return file.readAsString();
  }

  /// Save file content
  Future<void> saveFileContent(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Create a new folder under [parentPath]
  Future<void> createDirectory(String parentPath, String folderName) async {
    final trimmed = folderName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Folder name cannot be empty');
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      throw Exception('Folder name contains invalid characters');
    }

    final fullPath = p.join(parentPath, trimmed);
    final directory = Directory(fullPath);
    if (await directory.exists()) {
      throw Exception('Folder already exists: $trimmed');
    }
    await directory.create(recursive: false);
  }

  /// Open file with external application
  Future<void> openFileExternally(String path) async {
    await openPathExternally(path);
  }

  /// Open a file or folder with external application
  Future<void> openPathExternally(String path) async {
    if (Platform.isAndroid) {
      await StorageService.instance.openPathExternally(path);
      return;
    }

    final type = await FileSystemEntity.type(path, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      throw Exception('Path does not exist: $path');
    }

    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    throw Exception('Cannot open path: $path');
  }

  /// Get available storage directories
  Future<List<String>> getStorageDirectories() async {
    final directories = <String>[];

    if (Platform.isAndroid) {
      final hasStoragePermission =
          await StorageService.instance.checkStoragePermission();
      if (hasStoragePermission) {
        final externalStoragePath =
            await StorageService.instance.getExternalStoragePath();
        if (externalStoragePath != null &&
            await _isReadableDirectory(externalStoragePath)) {
          directories.add(externalStoragePath);
        }
      }

      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          if (await _isReadableDirectory(dir.path) &&
              !directories.contains(dir.path)) {
            directories.add(dir.path);
          }
        }
      }

      final docs = await _getAppDocumentsPath();
      if (!directories.contains(docs)) {
        directories.add(docs);
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && await _isReadableDirectory(home)) {
        directories.add(home);
      }
      if (await _isReadableDirectory('/')) {
        directories.add('/');
      }
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

  Future<String> _getAppDocumentsPath() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<bool> _isReadableDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;
      await directory.list(followLinks: false).take(1).toList();
      return true;
    } catch (_) {
      return false;
    }
  }
}
