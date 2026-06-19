import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';

const String _baseUrl = 'http://10.0.2.2:8000/v1';

typedef OnSessionExpired = void Function();

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = AuthStorage();


  OnSessionExpired? onSessionExpired;

 
  Completer<bool>? _refreshCompleter;

  
  static const _noRefreshPaths = [
    '/auth/login',
    '/auth/register',
    '/auth/verify-email',
    '/auth/refresh',
    '/auth/resend-verification',
    '/auth/forgot-password',
    '/auth/reset-password',
  ];

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isRetry = error.requestOptions.extra['_retried'] == true;
        if (error.response?.statusCode == 401 &&
            !_noRefreshPaths.contains(error.requestOptions.path) &&
            !isRetry) {
          final refreshed = await _refreshWithLock();
          if (refreshed) {
            final token = await _storage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            error.requestOptions.extra['_retried'] = true;
            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.reject(e);
            }
          }
          return handler.reject(error);
        }
        if (kDebugMode) {
          print('API Error: ${error.response?.statusCode} ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  
  Future<bool> _refreshWithLock() async {
   
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final result = await _tryRefresh();
      _refreshCompleter!.complete(result);
      return result;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      
      final freshDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await freshDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      await _storage.saveTokens(
        accessToken: response.data['access_token'],
        refreshToken: response.data['refresh_token'],
      );
      return true;
    } catch (_) {
      
      await _storage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
  }
}
