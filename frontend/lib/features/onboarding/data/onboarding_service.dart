import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class OnboardingService {
  final Dio _dio = ApiClient().dio;

  Future<bool> checkStatus() async {
    final response = await _dio.get('/onboarding/status');
    return response.data['has_profile'] as bool;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/onboarding');
    return response.data as Map<String, dynamic>;
  }

  Future<void> complete({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
  }) async {
    await _dio.post('/onboarding', data: {
      'level': level,
      'years_experience': yearsExperience,
      'target_jobs': targetJobs,
      'city': city,
      'province': province,
      'language': language,
      // ignore: use_null_aware_elements
      if (previousField != null) 'previous_field': previousField,
      'skills': skills,
    });
  }
}
