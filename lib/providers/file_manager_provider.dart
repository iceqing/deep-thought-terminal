import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

class FileManagerProvider extends ChangeNotifier {
  final FileService _fileService = FileService();

  String _currentPath = '';
  List<FileItem> _fileList = [];
  bool _isLoading = false;
  String? _error;
  final List<String> _history = [];
  bool _initialized = false;
  bool _hasStoragePermission = true;
  bool _showHiddenFiles = true;

  String get currentPath => _currentPath;
  List<FileItem> get fileList => _fileList;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  bool get canGoBack => _history.isNotEmpty;
  bool get hasStoragePermission => _hasStoragePermission;
  bool get showHiddenFiles => _showHiddenFiles;
  bool get canGoParent {
    if (_currentPath.isEmpty) return false;
    return _fileService.getParentDirectory(_currentPath) != _currentPath;
  }

  Future<void> init() async {
    if (_initialized) return;

    _setLoading(true);
    try {
      await checkStoragePermission();
      _currentPath = await _fileService.getInitialDirectory();
      await refresh();
      _initialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> navigateTo(String path) async {
    _setLoading(true);
    _error = null;

    try {
      // Add current path to history before navigating
      if (_currentPath.isNotEmpty) {
        _history.add(_currentPath);
      }

      _currentPath = path;
      await refresh();
    } catch (e) {
      _error = e.toString();
      // Go back to previous path on error
      if (_history.isNotEmpty) {
        _currentPath = _history.removeLast();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> goBack() async {
    if (_history.isEmpty) return;

    _setLoading(true);
    _error = null;

    try {
      _currentPath = _history.removeLast();
      await refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    _setLoading(true);
    _error = null;

    try {
      final items = await _fileService.getFileItems(
        _currentPath,
        includeHidden: _showHiddenFiles,
      );
      _fileList = items
          .map((item) => FileItem(
                name: item['name'],
                path: item['path'],
                isDirectory: item['isDirectory'],
                size: item['size'],
                modifiedDate: item['modifiedDate'],
                permissions: item['permissions'],
              ))
          .toList();
    } catch (e) {
      _error = e.toString();
      _fileList = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> navigateToParent() async {
    final parentPath = _fileService.getParentDirectory(_currentPath);
    if (parentPath != _currentPath) {
      await navigateTo(parentPath);
    }
  }

  Future<String> getFileContent(String path) async {
    return _fileService.getFileContent(path);
  }

  Future<void> saveFileContent(String path, String content) async {
    await _fileService.saveFileContent(path, content);
    await refresh();
  }

  Future<void> createFolder(String folderName) async {
    _setLoading(true);
    _error = null;
    try {
      await _fileService.createDirectory(_currentPath, folderName);
      await refresh();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> openFileExternally(String path) async {
    await _fileService.openFileExternally(path);
  }

  Future<void> openCurrentDirectoryExternally() async {
    await _fileService.openPathExternally(_currentPath);
  }

  Future<List<String>> getStorageDirectories() async {
    return _fileService.getStorageDirectories();
  }

  Future<void> checkStoragePermission() async {
    _hasStoragePermission =
        await StorageService.instance.checkStoragePermission();
    notifyListeners();
  }

  Future<bool> requestStoragePermission() async {
    final granted = await StorageService.instance.requestStoragePermission();
    _hasStoragePermission = granted;
    notifyListeners();
    return granted;
  }

  Future<void> setShowHiddenFiles(bool value) async {
    if (_showHiddenFiles == value) return;
    _showHiddenFiles = value;
    notifyListeners();
    await refresh();
  }

  Future<void> navigateHome() async {
    _setLoading(true);
    _error = null;

    try {
      final homePath = await _fileService.getHomeDirectory();
      if (_currentPath.isNotEmpty && _currentPath != homePath) {
        _history.add(_currentPath);
      }

      _currentPath = homePath;
      await refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
