import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ssh_host.dart';

class SSHProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  List<SSHHost> _hosts = [];
  bool _initialized = false;

  List<SSHHost> get hosts => List.unmodifiable(_hosts);
  bool get initialized => _initialized;

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
  }

  Future<void> updateHost(SSHHost host) async {
    final index = _hosts.indexWhere((element) => element.id == host.id);
    if (index != -1) {
      _hosts[index] = host;
      await _saveHosts();
    }
  }

  Future<void> removeHost(String id) async {
    _hosts.removeWhere((element) => element.id == id);
    await _saveHosts();
  }
}
