import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class UserService {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    final data = <String, String>{};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    final response = await _dio.put('/users/me', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('/users/me/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    await _dio.post('/users/me/change-email', data: {
      'new_email': newEmail,
      'password': password,
    });
  }

  Future<void> confirmEmailChange({required String code}) async {
    await _dio.post('/users/me/confirm-email-change', data: {
      'code': code,
    });
  }

  Future<void> resendEmailVerification() async {
    await _dio.post('/users/me/resend-email-verification');
  }
}
