import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// 存储服务 - 处理外部存储访问权限和符号链接设置
/// 类似 Termux 的 termux-setup-storage 功能
class StorageService {
  static const _channel = MethodChannel('com.dpterm/storage');
  static StorageService? _instance;

  final _permissionController = StreamController<bool>.broadcast();

  StorageService._() {
    _setupMethodCallHandler();
  }

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// 权限变化流
  Stream<bool> get onPermissionChanged => _permissionController.stream;

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionResult') {
        final granted = call.arguments['granted'] as bool? ?? false;
        _permissionController.add(granted);
      }
    });
  }

  /// 检查存储权限
  Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('checkStoragePermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 请求存储权限
  /// 返回一个 Future，在用户授权后完成
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // 先检查是否已有权限
      if (await checkStoragePermission()) {
        return true;
      }

      // 请求权限
      await _channel.invokeMethod('requestStoragePermission');

      // 等待权限结果
      final result = await onPermissionChanged.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => false,
      );

      return result;
    } catch (e) {
      return false;
    }
  }

  /// 设置存储符号链接
  /// [homePath] 是用户的 home 目录路径
  Future<StorageSetupResult> setupStorageSymlinks(String homePath) async {
    if (!Platform.isAndroid) {
      return StorageSetupResult(
        success: false,
        errors: ['Storage setup is only available on Android'],
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setupStorageSymlinks',
        {'homePath': homePath},
      );

      if (result == null) {
        return StorageSetupResult(
          success: false,
          errors: ['Failed to setup storage'],
        );
      }

      return StorageSetupResult(
        success: result['success'] as bool? ?? false,
        created: (result['created'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        errors: (result['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
      );
    } catch (e) {
      return StorageSetupResult(
        success: false,
        errors: ['Exception: $e'],
      );
    }
  }

  /// 获取外部存储路径
  Future<String?> getExternalStoragePath() async {
    if (!Platform.isAndroid) return null;

    try {
      return await _channel.invokeMethod<String>('getExternalStoragePath');
    } catch (e) {
      return null;
    }
  }

  /// 执行完整的存储设置流程
  /// 1. 检查权限
  /// 2. 如果没有权限，请求权限
  /// 3. 如果有权限，设置符号链接
  Future<StorageSetupResult> setupStorage(String homePath) async {
    // 检查权限
    var hasPermission = await checkStoragePermission();

    // 如果没有权限，请求权限
    if (!hasPermission) {
      hasPermission = await requestStoragePermission();
    }

    // 如果仍然没有权限，返回错误
    if (!hasPermission) {
      return StorageSetupResult(
        success: false,
        errors: ['Storage permission denied'],
      );
    }

    // 设置符号链接
    return await setupStorageSymlinks(homePath);
  }

  void dispose() {
    _permissionController.close();
  }
}

/// 存储设置结果
class StorageSetupResult {
  final bool success;
  final List<String> created;
  final List<String> errors;

  StorageSetupResult({
    required this.success,
    this.created = const [],
    this.errors = const [],
  });

  @override
  String toString() {
    if (success) {
      return 'Storage setup completed successfully.\n'
          'Created symlinks:\n${created.map((e) => '  $e').join('\n')}';
    } else {
      return 'Storage setup failed.\n'
          'Errors:\n${errors.map((e) => '  $e').join('\n')}';
    }
  }
}
