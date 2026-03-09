import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

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

  Future<void> generate() async {
    await _dio.post('/roadmap/generate');
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _dio.get('/roadmap/history');
    return response.data as List<dynamic>;
  }

  /// Retourne {used, limit, remaining, resets_at}
  Future<Map<String, dynamic>> getRegenerationStatus() async {
    final response = await _dio.get('/roadmap/regeneration-status');
    return response.data as Map<String, dynamic>;
  }

  /// Met à jour toutes les phases (réordonnement, édition, notes, etc.)
  Future<Map<String, dynamic>> updatePhases(
      String roadmapId, List<Map<String, dynamic>> phases) async {
    final response = await _dio.put(
      '/roadmap/$roadmapId/phases',
      data: {'phases': phases},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Ajoute une phase custom
  Future<Map<String, dynamic>> addPhase(
      String roadmapId, Map<String, dynamic> phase) async {
    final response = await _dio.post(
      '/roadmap/$roadmapId/phases',
      data: phase,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Supprime une phase par numéro
  Future<Map<String, dynamic>> deletePhase(
      String roadmapId, int phaseNumber) async {
    final response = await _dio.delete(
      '/roadmap/$roadmapId/phases/$phaseNumber',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Toggle completed sur une phase
  Future<Map<String, dynamic>> togglePhaseComplete(
      String roadmapId, int phaseNumber) async {
    final response = await _dio.patch(
      '/roadmap/$roadmapId/phases/$phaseNumber/complete',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Toggle completed sur une action
  Future<Map<String, dynamic>> toggleActionComplete(
      String roadmapId, int phaseNumber, int actionIndex) async {
    final response = await _dio.patch(
      '/roadmap/$roadmapId/phases/$phaseNumber/actions/$actionIndex/complete',
    );
    return response.data as Map<String, dynamic>;
  }
}
