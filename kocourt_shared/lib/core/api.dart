import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_error_bus.dart';

class Api {
  static final Api _instance = Api._internal();
  factory Api() => _instance;
  Api._internal();

  // CI and staging builds inject an isolated API; release builds retain the
  // public production URL. This avoids accidentally running test traffic
  // against production.
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (kIsWeb && kDebugMode)
          ? 'http://localhost/playbook/backend'
          : 'https://www.kocourt.com/api';

  late final Dio dio;
  String? _token;
  bool _handlingUnauthorized = false;

  /// Called once when a request returns 401 while a session token was set.
  Future<void> Function()? onUnauthorized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    ));

    _applyAuthHeaders(_token);

    // Method tunneling interceptor: convert DELETE/PUT to POST + X-HTTP-Method-Override
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          options.headers['X-Authorization'] = 'Bearer $token';
          options.headers['X-Auth-Token'] = token;
        } else {
          options.headers.remove('Authorization');
          options.headers.remove('X-Authorization');
          options.headers.remove('X-Auth-Token');
        }
        if (options.method == 'DELETE' || options.method == 'PUT') {
          options.headers['X-HTTP-Method-Override'] = options.method;
          options.method = 'POST';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final authFailure = status == 401 || _looksUnauthenticated(error);

        // Screens already show their own failures. Toasting every 401 as
        // "Unauthenticated" floods the owner shell when several tabs load at once.
        if (!authFailure) {
          ApiErrorBus.publish(failureMessage(error));
        } else if (_token != null && _token!.isNotEmpty) {
          await _notifyUnauthorized();
        }

        handler.next(error);
      },
    ));
  }

  bool _looksUnauthenticated(DioException error) {
    final data = error.response?.data;
    if (data is! Map) return false;
    final text = '${data['error'] ?? data['message'] ?? ''}'.toLowerCase();
    return text.contains('unauthenticated') || text.contains('authentication required');
  }

  Future<void> _notifyUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      final hook = onUnauthorized;
      if (hook != null) await hook();
    } finally {
      _handlingUnauthorized = false;
    }
  }

  void _applyAuthHeaders(String? token) {
    try {
      if (token != null && token.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $token';
        dio.options.headers['X-Authorization'] = 'Bearer $token';
        dio.options.headers['X-Auth-Token'] = token;
      } else {
        dio.options.headers.remove('Authorization');
        dio.options.headers.remove('X-Authorization');
        dio.options.headers.remove('X-Auth-Token');
      }
    } catch (_) {}
  }

  /// A short, safe message suitable for a toast or inline error state.
  /// This keeps network and validation failures consistent throughout the app.
  static String failureMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Unable to reach KoCourt. Check your connection and try again.';
      }
    }
    return fallback;
  }

  void setToken(String? token) {
    _token = (token != null && token.isNotEmpty) ? token : null;
    _applyAuthHeaders(_token);
  }

  String? get token => _token;

  // Convenience methods
  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      dio.delete(path, data: data);

  Future<Response> uploadFile(String path, dynamic file) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(file.path),
    });
    return dio.post(path, data: formData);
  }
}
