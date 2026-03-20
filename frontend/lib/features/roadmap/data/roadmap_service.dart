import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:http_parser/http_parser.dart';

class RoadmapService {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _dio.get('/roadmap/status');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRoadmap() async {
    final response = await _dio.get('/roadmap');
    return response.data as Map<String, dynamic>;
  }

  /// Génère un roadmap avec l'IA (envoie career + skills dans le body)
  Future<void> generateWithAI({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
  }) async {
    await _dio.post('/roadmap/generate', data: {
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

  /// Crée un roadmap manuellement (sans IA)
  Future<Map<String, dynamic>> createManual(
      List<String> targetJobs, List<Map<String, dynamic>> phases) async {
    final response = await _dio.post('/roadmap/manual', data: {
      'target_jobs': targetJobs,
      'phases': phases,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Extrait les compétences d'un CV (PDF)
  Future<List<Map<String, dynamic>>> extractSkills(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: MediaType('application', 'pdf'),
      ),
    });
    final response = await _dio.post('/roadmap/extract-skills', data: formData);
    final skills = response.data['skills'] as List;
    return skills.cast<Map<String, dynamic>>();
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _dio.get('/roadmap/history');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getRoadmapById(String roadmapId) async {
    final response = await _dio.get('/roadmap/$roadmapId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> restoreRoadmap(String roadmapId) async {
    final response = await _dio.post('/roadmap/$roadmapId/restore');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRegenerationStatus() async {
    final response = await _dio.get('/roadmap/regeneration-status');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePhases(
      String roadmapId, List<Map<String, dynamic>> phases) async {
    final response = await _dio.put(
      '/roadmap/$roadmapId/phases',
      data: {'phases': phases},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addPhase(
      String roadmapId, Map<String, dynamic> phase) async {
    final response = await _dio.post(
      '/roadmap/$roadmapId/phases',
      data: phase,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deletePhase(
      String roadmapId, int phaseNumber) async {
    final response = await _dio.delete(
      '/roadmap/$roadmapId/phases/$phaseNumber',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> togglePhaseComplete(
      String roadmapId, int phaseNumber) async {
    final response = await _dio.patch(
      '/roadmap/$roadmapId/phases/$phaseNumber/complete',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleActionComplete(
      String roadmapId, int phaseNumber, int actionIndex) async {
    final response = await _dio.patch(
      '/roadmap/$roadmapId/phases/$phaseNumber/actions/$actionIndex/complete',
    );
    return response.data as Map<String, dynamic>;
  }
}
