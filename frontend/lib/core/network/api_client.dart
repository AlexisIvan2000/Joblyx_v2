import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';

const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator → host machine
// Use 'http://localhost:8000' for iOS simulator or web

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthStorage().getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('API Error: ${error.response?.statusCode} ${error.message}');
        }
        handler.next(error);
      },
    ));
  }
}
