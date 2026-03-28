import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _isLoggedIn = false;
  bool _guestModeEnabled = false; // 游客模式
  String? _token;
  String? _userId;
  String? _email;

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';

  bool get isLoggedIn => _isLoggedIn;
  bool get guestModeEnabled => _guestModeEnabled;
  bool get initialized => _initialized;
  String? get token => _token;
  String? get userId => _userId;
  String? get email => _email;

  Future<void> init() async {
    debugPrint('[AuthProvider] init start');
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString(_tokenKey);
    _userId = _prefs.getString(_userIdKey);
    _email = _prefs.getString(_emailKey);
    _isLoggedIn = _token != null && _token!.isNotEmpty;
    debugPrint(
        '[AuthProvider] init: token=${_token != null}, isLoggedIn=$_isLoggedIn');
    if (_isLoggedIn && _token != null) {
      ApiService.setToken(_token!);
    }
    _initialized = true;
    notifyListeners();
    debugPrint('[AuthProvider] init complete');
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http
          .post(
            ApiService.buildUri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _email = email;

        // 从 token 中解析 user_id (这里简化处理，实际应该从 API 返回)
        // 或者我们可以使用 email 作为 user_id
        _userId = email;

        // 保存到本地
        await _prefs.setString(_tokenKey, _token!);
        await _prefs.setString(_userIdKey, _userId!);
        await _prefs.setString(_emailKey, _email!);

        _isLoggedIn = true;
        ApiService.setToken(_token!);
        debugPrint('[AuthProvider] login success, isLoggedIn=$_isLoggedIn');
        notifyListeners();
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<bool> register(String email, String password, String code) async {
    try {
      final response = await http
          .post(
            ApiService.buildUri('/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'code': code,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _userId = email;
        _email = email;

        await _prefs.setString(_tokenKey, _token!);
        await _prefs.setString(_userIdKey, _userId!);
        await _prefs.setString(_emailKey, _email!);

        _isLoggedIn = true;
        ApiService.setToken(_token!);
        debugPrint('[AuthProvider] register success, isLoggedIn=$_isLoggedIn');
        notifyListeners();
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      debugPrint('Register error: $e');
      rethrow;
    }
  }

  Future<void> sendVerificationCode(String email) async {
    try {
      final response = await http
          .post(
            ApiService.buildUri('/auth/send-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to send code');
      }
    } catch (e) {
      debugPrint('Send code error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;
    _isLoggedIn = false;

    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_emailKey);

    ApiService.clearToken();
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    _isLoggedIn = true;
    _prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  /// 跳过登录（游客模式）
  void skipLogin() {
    _guestModeEnabled = true;
    notifyListeners();
  }

  /// 从游客模式切回登录流程
  void requireLogin() {
    if (_isLoggedIn) return;
    _guestModeEnabled = false;
    notifyListeners();
  }
}
