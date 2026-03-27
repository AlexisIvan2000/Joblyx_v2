import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';

const String _baseUrl = 'https://api.joblyx.com'; 

/// Callback appelé quand la session expire (refresh token invalide).
/// Permet au niveau app de rediriger vers le login.
typedef OnSessionExpired = void Function();

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = AuthStorage();

  /// Callback externe pour gérer l'expiration de session.
  OnSessionExpired? onSessionExpired;

  // Lock pour éviter les refresh concurrents
  Completer<bool>? _refreshCompleter;

  // Endpoints exemptés du refresh automatique
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
        // Si 401, pas un endpoint exempt, et pas déjà un retry → tenter le refresh
        final isRetry = error.requestOptions.extra['_retried'] == true;
        if (error.response?.statusCode == 401 &&
            !_noRefreshPaths.contains(error.requestOptions.path) &&
            !isRetry) {
          final refreshed = await _refreshWithLock();
          if (refreshed) {
            // Relancer la requête une seule fois avec le nouveau token
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
          // Refresh échoué → session expirée
          return handler.reject(error);
        }
        if (kDebugMode) {
          print('API Error: ${error.response?.statusCode} ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  /// Refresh avec lock : le premier appel fait le refresh,
  /// les appels concurrents attendent le même résultat.
  Future<bool> _refreshWithLock() async {
    // Si un refresh est déjà en cours, attendre son résultat
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
      // Dio séparé pour éviter les interceptors récursifs
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
      // Refresh échoué → nettoyer les tokens et notifier
      await _storage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
  }
}
