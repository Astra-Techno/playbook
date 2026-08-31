import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static final Api _instance = Api._internal();
  factory Api() => _instance;
  Api._internal();

  // Change this to your production URL
  static final String baseUrl = (kIsWeb && kDebugMode)
      ? 'http://localhost/playbook/backend'
      : 'https://www.kocourt.com/api';

  late final Dio dio;
  String? _token;

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

    if (_token != null) {
      dio.options.headers['Authorization'] = 'Bearer $_token';
    }

    // Method tunneling interceptor: convert DELETE/PUT to POST + X-HTTP-Method-Override
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'DELETE' || options.method == 'PUT') {
          options.headers['X-HTTP-Method-Override'] = options.method;
          options.method = 'POST';
        }
        handler.next(options);
      },
    ));
  }

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      dio.options.headers.remove('Authorization');
    }
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
