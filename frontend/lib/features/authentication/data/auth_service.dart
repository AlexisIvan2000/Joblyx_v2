import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/features/authentication/domain/auth_failure.dart';

class AuthService {
  final Dio _dio = ApiClient().dio;
  final AuthStorage _storage = AuthStorage();

  /// Register a new user. Returns the success message.
  /// Throws [AuthException] on failure.
  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final color = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final name = Uri.encodeComponent('$firstName $lastName');
      final avatarUrl =
          'https://ui-avatars.com/api/?name=$name&background=$color&color=fff&size=128&bold=true';

      final response = await _dio.post('/auth/register', data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'avatar_url': avatarUrl,
      });
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Verify email with OTP code. Saves tokens on success.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post('/auth/verify-email', data: {
        'email': email,
        'code': code,
      });
      await _storage.saveTokens(
        accessToken: response.data['access_token'],
        refreshToken: response.data['refresh_token'],
      );
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Login with email and password. Saves tokens on success.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _storage.saveTokens(
        accessToken: response.data['access_token'],
        refreshToken: response.data['refresh_token'],
      );
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Resend verification code.
  Future<String> resendVerification({required String email}) async {
    try {
      final response = await _dio.post('/auth/resend-verification', data: {
        'email': email,
      });
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Demande un code de réinitialisation de mot de passe.
  Future<String> forgotPassword({required String email}) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Réinitialise le mot de passe avec le code OTP.
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      });
      return response.data['message'] as String;
    } on DioException catch (e) {
      throw AuthException.fromDioError(e);
    }
  }

  /// Logout the current user.
  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    debugPrint('[AUTH] logout: refreshToken=${refreshToken != null ? "exists" : "null"}');
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {
          'refresh_token': refreshToken,
        });
        debugPrint('[AUTH] logout: backend call success');
      } catch (e) {
        debugPrint('[AUTH] logout: backend call failed: $e');
      }
    }
    await _storage.clearTokens();
    // Vérifier que les tokens sont bien effacés
    final check = await _storage.getAccessToken();
    debugPrint('[AUTH] logout: tokens cleared, accessToken=${check != null ? "STILL EXISTS" : "null"}');
  }

  /// Sauvegarde les tokens reçus via le deep link LinkedIn.
  Future<void> saveLinkedInTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class AuthException implements Exception {
  /// i18n key resolved via [AuthFailure].
  final String key;
  final int? statusCode;

  AuthException(this.key, {this.statusCode});

  factory AuthException.fromDioError(DioException e) {
    final data = e.response?.data;
    final statusCode = e.response?.statusCode;

    if (data is Map && data.containsKey('detail')) {
      final detail = data['detail'] as String;
      return AuthException(
        AuthFailure.resolve(detail, statusCode: statusCode),
        statusCode: statusCode,
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AuthException('auth_error.connection_timeout', statusCode: statusCode);
    }

    if (e.type == DioExceptionType.connectionError) {
      return AuthException('auth_error.connection_error', statusCode: statusCode);
    }

    return AuthException(
      AuthFailure.resolve(null, statusCode: statusCode),
      statusCode: statusCode,
    );
  }
  

  @override
  String toString() => key;
}
