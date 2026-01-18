import 'dart:io';
import 'package:flutter/services.dart';

/// 音量键服务 - 处理Android音量键作为Ctrl/Alt修饰键
class VolumeKeyService {
  static const _channel = MethodChannel('com.dpterm/volume_keys');
  static VolumeKeyService? _instance;

  Function(String key, String action)? onVolumeKey;
  bool _initialized = false;

  VolumeKeyService._();

  static VolumeKeyService get instance {
    _instance ??= VolumeKeyService._();
    return _instance!;
  }

  /// 初始化服务
  void init() {
    if (_initialized || !Platform.isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeKey') {
        final key = call.arguments['key'] as String;
        final action = call.arguments['action'] as String;
        onVolumeKey?.call(key, action);
      }
    });

    _initialized = true;
  }

  /// 设置是否启用音量键功能
  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('setVolumeKeysEnabled', {'enabled': enabled});
    } catch (e) {
      // 忽略错误，可能在非Android平台上
    }
  }
}
