import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:http_parser/http_parser.dart';

class UserService {
  final Dio _dio;

  UserService() : _dio = ApiClient().dio;
  UserService.withDio(this._dio);

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

  Future<void> setPassword({required String newPassword}) async {
    await _dio.post('/users/me/set-password', data: {
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

  /// Upload une photo de profil (JPEG, PNG ou WebP, max 10 Mo).
  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post('/users/me/avatar', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Supprime le compte de l'utilisateur.
  Future<void> deleteAccount(String email) async {
    await _dio.delete('/users/me', queryParameters: {'email': email});
  }
}
