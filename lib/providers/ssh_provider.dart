import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ssh_host.dart';
import '../services/api_service.dart';

class SSHProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  List<SSHHost> _hosts = [];
  bool _initialized = false;
  bool _syncedFromApi = false;

  List<SSHHost> get hosts => List.unmodifiable(_hosts);
  bool get initialized => _initialized;
  bool get syncedFromApi => _syncedFromApi;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadHosts();
    _initialized = true;
    notifyListeners();
  }

  void _loadHosts() {
    final jsonList = _prefs.getStringList('ssh_hosts');
    if (jsonList != null) {
      try {
        _hosts = jsonList
            .map((e) => SSHHost.fromJson(jsonDecode(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading SSH hosts: $e');
        _hosts = [];
      }
    }
  }

  Future<void> _saveHosts() async {
    final jsonList = _hosts.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList('ssh_hosts', jsonList);
    notifyListeners();
  }

  Future<void> addHost(SSHHost host) async {
    _hosts.add(host);
    await _saveHosts();

    // 尝试同步到 API
    await _syncToApi();
  }

  Future<void> updateHost(SSHHost host) async {
    final index = _hosts.indexWhere((element) => element.id == host.id);
    if (index != -1) {
      _hosts[index] = host;
      await _saveHosts();

      // 尝试同步到 API
      await _syncToApi();
    }
  }

  Future<void> removeHost(String id) async {
    _hosts.removeWhere((element) => element.id == id);
    await _saveHosts();

    // 尝试同步到 API
    await _syncToApi();
  }

  /// 从 API 同步 SSH 主机
  Future<void> syncFromApi() async {
    try {
      final apiHosts = await ApiService.getSSHHosts();
      if (apiHosts.isNotEmpty) {
        _hosts = apiHosts.map((host) => SSHHost(
          id: host['host_id'] ?? '',
          alias: host['alias'] ?? '',
          host: host['host'] ?? '',
          port: host['port'] ?? 22,
          username: host['username'] ?? '',
          args: host['args'] ?? '',
        )).toList();
        await _saveHosts();
        _syncedFromApi = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing SSH hosts from API: $e');
    }
  }

  /// 同步到 API
  Future<void> _syncToApi() async {
    try {
      // 获取当前 API 中的主机
      final apiHosts = await ApiService.getSSHHosts();
      final apiHostIds = apiHosts.map((h) => h['host_id'] as String).toSet();

      // 遍历本地主机，同步到 API
      for (final host in _hosts) {
        if (apiHostIds.contains(host.id)) {
          // 更新
          await ApiService.updateSSHHost(host.id, {
            'alias': host.alias,
            'host': host.host,
            'port': host.port,
            'username': host.username,
            'args': host.args,
          });
        } else {
          // 创建
          await ApiService.createSSHHost({
            'alias': host.alias,
            'host': host.host,
            'port': host.port,
            'username': host.username,
            'args': host.args,
          });
        }
      }

      // 删除 API 中不存在于本地的
      for (final apiHost in apiHosts) {
        final hostId = apiHost['host_id'] as String;
        if (!_hosts.any((h) => h.id == hostId)) {
          await ApiService.deleteSSHHost(hostId);
        }
      }
    } catch (e) {
      debugPrint('Error syncing SSH hosts to API: $e');
    }
  }
}
