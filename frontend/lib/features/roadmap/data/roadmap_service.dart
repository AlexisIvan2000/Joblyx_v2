import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:http_parser/http_parser.dart';

class RoadmapService {
  final Dio _dio;

  RoadmapService() : _dio = ApiClient().dio;
  RoadmapService.withDio(this._dio);

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _dio.get('/roadmap/status');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRoadmap() async {
    final response = await _dio.get('/roadmap');
    return response.data as Map<String, dynamic>;
  }

  /// Generates a roadmap with AI via SSE streaming.
  /// Yields SSE events as maps: {event: "status"|"chunk"|"complete"|"error", data: {...}}
  Stream<Map<String, dynamic>> generateWithAI({
    required String level,
    required int yearsExperience,
    required List<String> targetJobs,
    required String city,
    required String province,
    required String language,
    String? previousField,
    required List<Map<String, String>> skills,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post(
      '/roadmap/generate',
      data: {
        'level': level,
        'years_experience': yearsExperience,
        'target_jobs': targetJobs,
        'city': city,
        'province': province,
        'language': language,
        // ignore: use_null_aware_elements
        if (previousField != null) 'previous_field': previousField,
        'skills': skills,
      },
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      // Parse SSE events from buffer
      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final rawEvent = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        String? eventType;
        String? eventData;

        for (final line in rawEvent.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7);
          } else if (line.startsWith('data: ')) {
            eventData = line.substring(6);
          }
        }

        if (eventType != null && eventData != null) {
          try {
            final parsed = jsonDecode(eventData) as Map<String, dynamic>;
            yield {'event': eventType, 'data': parsed};
          } catch (_) {
            yield {'event': eventType, 'data': {'raw': eventData}};
          }
        }
      }
    }
  }

  /// Regenerates a roadmap using existing career data (no form needed).
  /// Returns SSE events as maps.
  Stream<Map<String, dynamic>> regenerate({CancelToken? cancelToken}) async* {
    final response = await _dio.post(
      '/roadmap/regenerate',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final rawEvent = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        String? eventType;
        String? eventData;

        for (final line in rawEvent.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7);
          } else if (line.startsWith('data: ')) {
            eventData = line.substring(6);
          }
        }

        if (eventType != null && eventData != null) {
          try {
            final parsed = jsonDecode(eventData) as Map<String, dynamic>;
            yield {'event': eventType, 'data': parsed};
          } catch (_) {
            yield {'event': eventType, 'data': {'raw': eventData}};
          }
        }
      }
    }
  }

  /// Gets the user's career profile + skills
  Future<Map<String, dynamic>> getCareerProfile() async {
    final response = await _dio.get('/roadmap/career');
    return response.data as Map<String, dynamic>;
  }

  /// Updates the user's career profile + skills
  Future<Map<String, dynamic>> updateCareerProfile(
      Map<String, dynamic> data) async {
    final response = await _dio.put('/roadmap/career', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Creates a roadmap manually (no AI)
  Future<Map<String, dynamic>> createManual(
      List<Map<String, dynamic>> phases) async {
    final response = await _dio.post('/roadmap/manual', data: {
      'phases': phases,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Extrait les skills d'un CV via SSE streaming.
  /// Yield des events : {event: "status"|"chunk"|"skills"|"complete"|"error", data: {...}}
  Stream<Map<String, dynamic>> extractSkillsStream(String filePath, {CancelToken? cancelToken}) async* {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: MediaType('application', 'pdf'),
      ),
    });
    final response = await _dio.post(
      '/roadmap/extract-skills',
      data: formData,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      while (buffer.contains('\n\n')) {
        final eventEnd = buffer.indexOf('\n\n');
        final rawEvent = buffer.substring(0, eventEnd);
        buffer = buffer.substring(eventEnd + 2);

        String? eventType;
        String? eventData;

        for (final line in rawEvent.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7);
          } else if (line.startsWith('data: ')) {
            eventData = line.substring(6);
          }
        }

        if (eventType != null && eventData != null) {
          try {
            final parsed = jsonDecode(eventData) as Map<String, dynamic>;
            yield {'event': eventType, 'data': parsed};
          } catch (_) {
            yield {'event': eventType, 'data': {'raw': eventData}};
          }
        }
      }
    }
  }

  /// Archive la roadmap active sans en créer une nouvelle.
  Future<void> archiveRoadmap() async {
    await _dio.post('/roadmap/archive');
  }

  /// Supprime une roadmap et ses phases.
  Future<void> deleteRoadmap(String roadmapId) async {
    await _dio.delete('/roadmap/$roadmapId');
  }

  /// Supprime toutes les roadmaps archivées.
  Future<int> deleteAllArchived() async {
    final response = await _dio.delete('/roadmap');
    return response.data['count'] as int? ?? 0;
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

  // Phase endpoints (use phase ID)

  Future<Map<String, dynamic>> addPhase(Map<String, dynamic> phase) async {
    final response = await _dio.post('/roadmap/phases', data: phase);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePhase(String phaseId) async {
    await _dio.delete('/roadmap/phases/$phaseId');
  }

  Future<Map<String, dynamic>> updatePhase(
      String phaseId, Map<String, dynamic> data) async {
    final response = await _dio.put('/roadmap/phases/$phaseId', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> togglePhaseComplete(String phaseId) async {
    final response = await _dio.patch('/roadmap/phases/$phaseId/complete');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleActionComplete(
      String phaseId, int actionIndex) async {
    final response = await _dio.patch(
      '/roadmap/phases/$phaseId/actions/$actionIndex/complete',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleSkillComplete(
      String phaseId, int skillIndex) async {
    final response = await _dio.patch(
      '/roadmap/phases/$phaseId/skills/$skillIndex/complete',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> reorderPhases(List<String> phaseIds) async {
    await _dio.put('/roadmap/phases/reorder', data: {
      'phase_ids': phaseIds,
    });
  }
}
