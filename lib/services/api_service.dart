import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _defaultBaseDomain = 'https://deep.iceq.cc';
  static const String _apiBaseUrlEnvKey = 'API_BASE_URL';

  static String get _baseUrl {
    final fromEnv =
        dotenv.isInitialized ? dotenv.maybeGet(_apiBaseUrlEnvKey)?.trim() : null;
    final raw =
        (fromEnv == null || fromEnv.isEmpty) ? _defaultBaseDomain : fromEnv;
    final normalized =
        raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    return normalized.endsWith('/api') ? normalized : '$normalized/api';
  }

  /// 当前生效的后端基础域名（不含 /api）
  static String get backendServer {
    final base = _baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  /// 当前生效的 API 基础地址（含 /api）
  static String get apiBaseUrl => _baseUrl;

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static void setToken(String token) {
    _token = token;
  }

  static void clearToken() {
    _token = null;
  }

  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Uri buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters:
          queryParameters.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  // ==================== SSH Hosts API ====================

  static Future<List<Map<String, dynamic>>> getSSHHosts() async {
    try {
      final response = await http
          .get(
            buildUri('/terminal/ssh-hosts'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load SSH hosts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting SSH hosts: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createSSHHost(
      Map<String, dynamic> host) async {
    try {
      final response = await http
          .post(
            buildUri('/terminal/ssh-hosts'),
            headers: _headers,
            body: jsonEncode(host),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create SSH host: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating SSH host: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateSSHHost(
      String hostId, Map<String, dynamic> host) async {
    try {
      final response = await http
          .put(
            buildUri('/terminal/ssh-hosts/$hostId'),
            headers: _headers,
            body: jsonEncode(host),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update SSH host: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating SSH host: $e');
      return null;
    }
  }

  static Future<bool> deleteSSHHost(String hostId) async {
    try {
      final response = await http
          .delete(
            buildUri('/terminal/ssh-hosts/$hostId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting SSH host: $e');
      return false;
    }
  }

  // ==================== Terminal History API ====================

  static Future<List<Map<String, dynamic>>> getHistory(
      {int limit = 100}) async {
    try {
      debugPrint(
          '[HistoryDiag] API getHistory request: ${buildUri('/terminal/history', queryParameters: {
            'limit': limit
          })}');
      final response = await http
          .get(
            buildUri('/terminal/history', queryParameters: {'limit': limit}),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '[HistoryDiag] API getHistory status=${response.statusCode}, bodyLength=${response.body.length}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        debugPrint('[HistoryDiag] API getHistory items=${items.length}');
        return items.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[HistoryDiag] Error getting history: $e');
      return [];
    }
  }

  static Future<bool> addHistory(String command,
      {String sessionName = '', int exitCode = 0}) async {
    try {
      debugPrint(
          '[HistoryDiag] API addHistory request: ${buildUri('/terminal/history')}, command="$command", session="$sessionName", hasToken=${_token != null}');
      final response = await http
          .post(
            buildUri('/terminal/history'),
            headers: _headers,
            body: jsonEncode({
              'command': command,
              'session_name': sessionName,
              'exit_code': exitCode,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '[HistoryDiag] API addHistory status=${response.statusCode}, body=${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HistoryDiag] Error adding history: $e');
      return false;
    }
  }

  static Future<bool> clearHistory() async {
    try {
      final response = await http
          .delete(
            buildUri('/terminal/history'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return false;
    }
  }

  static Future<bool> deleteHistoryItem({
    required int executedAt,
    String? command,
  }) async {
    try {
      final query = <String, dynamic>{'executed_at': executedAt};
      if (command != null && command.isNotEmpty) {
        query['command'] = command;
      }

      final response = await http
          .delete(
            buildUri('/terminal/history/item', queryParameters: query),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting history item: $e');
      return false;
    }
  }

  // ==================== Tasks API ====================

  static Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final response = await http
          .get(
            buildUri('/terminal/tasks'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createTask(
      Map<String, dynamic> task) async {
    try {
      final response = await http
          .post(
            buildUri('/terminal/tasks'),
            headers: _headers,
            body: jsonEncode(task),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateTask(
      String taskId, Map<String, dynamic> task) async {
    try {
      final response = await http
          .put(
            buildUri('/terminal/tasks/$taskId'),
            headers: _headers,
            body: jsonEncode(task),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update task: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      return null;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      final response = await http
          .delete(
            buildUri('/terminal/tasks/$taskId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting task: $e');
      return false;
    }
  }

  // ==================== Task Groups API ====================

  static Future<List<Map<String, dynamic>>> getTaskGroups() async {
    try {
      final response = await http
          .get(
            buildUri('/terminal/task-groups'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load task groups: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting task groups: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createTaskGroup(
      Map<String, dynamic> group) async {
    try {
      final response = await http
          .post(
            buildUri('/terminal/task-groups'),
            headers: _headers,
            body: jsonEncode(group),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create task group: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating task group: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateTaskGroup(
      String groupId, Map<String, dynamic> group) async {
    try {
      final response = await http
          .put(
            buildUri('/terminal/task-groups/$groupId'),
            headers: _headers,
            body: jsonEncode(group),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update task group: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating task group: $e');
      return null;
    }
  }

  static Future<bool> deleteTaskGroup(String groupId) async {
    try {
      final response = await http
          .delete(
            buildUri('/terminal/task-groups/$groupId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting task group: $e');
      return false;
    }
  }

  // ==================== Task Sync API ====================

  static Future<Map<String, dynamic>?> syncTasks(
      Map<String, dynamic> syncData) async {
    try {
      final taskCount = (syncData['tasks'] as List?)?.length ?? 0;
      final groupCount = (syncData['groups'] as List?)?.length ?? 0;
      debugPrint(
          '[TaskDiag] syncTasks request: ${buildUri('/terminal/tasks/sync')}, tasks=$taskCount, groups=$groupCount, hasToken=$hasToken');
      final response = await http
          .post(
            buildUri('/terminal/tasks/sync'),
            headers: _headers,
            body: jsonEncode(syncData),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '[TaskDiag] syncTasks status=${response.statusCode}, bodyLength=${response.body.length}');
      debugPrint('[TaskDiag] syncTasks responseBody=${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to sync tasks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing tasks: $e');
      return null;
    }
  }
}
