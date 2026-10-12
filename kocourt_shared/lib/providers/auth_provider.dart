import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isAdmin => _user?['role'] == 'admin';
  String get userName => _user?['name'] ?? '';
  String get userPhone => _user?['phone'] ?? '';
  String? get avatarUrl => _user?['avatar_url'];
  int? get userId => _user?['id'];
  String? get userBio => _user?['bio'];
  String? get skillLevel => _user?['skill_level'];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        _user = jsonDecode(userStr);
      } catch (_) {
        _user = null;
      }
    }
    notifyListeners();
  }

  Future<void> setAuth(Map<String, dynamic> userData, String tokenData) async {
    _user = userData;
    _token = tokenData;
    Api().setToken(tokenData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(userData));
    await prefs.setString('token', tokenData);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    Api().setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('token');
    notifyListeners();
  }

  Future<void> updateAvatar(String url) async {
    if (_user != null) {
      _user!['avatar_url'] = url;
      _saveUser();
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    if (_user?['id'] == null) return;
    try {
      final res = await Api().get('/auth/profile', params: {'user_id': _user!['id']});
      final fresh = res.data['user'];
      if (fresh != null) {
        _user = Map<String, dynamic>.from(fresh);
        _saveUser();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> sendOtp(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Api().post('/auth/send-otp', data: {'phone': phone});
      return null;
    } catch (e) {
      return _extractError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns: { 'success': true, 'new_user': false } or { 'error': '...' }
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String? name}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final payload = {'phone': phone, 'otp': otp};
      if (name != null) {
        payload['name'] = name;
        payload['role'] = 'user';
      }
      final res = await Api().post('/auth/verify-otp', data: payload);
      final data = res.data;

      if (data['new_user'] == true) {
        return {'new_user': true};
      }

      await setAuth(Map<String, dynamic>.from(data['user']), data['token']);
      return {'success': true};
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 404 || e.response?.data?['new_user'] == true)) {
        return {'new_user': true};
      }
      return {'error': _extractError(e)};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user));
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final msg = e.response?.data;
      if (msg is Map) return msg['message'] ?? 'Something went wrong. Try again.';
    }
    return 'Something went wrong. Try again.';
  }
}
