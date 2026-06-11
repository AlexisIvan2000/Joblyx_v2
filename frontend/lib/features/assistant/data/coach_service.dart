import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:frontend/core/network/api_client.dart';

class CoachService {
  final Dio _dio;

  CoachService() : _dio = ApiClient().dio;
  CoachService.withDio(this._dio);

  /// Lance l'analyse coach en SSE streaming.
  Stream<Map<String, dynamic>> analyzeStream({
    required String cvPath,
    required String jobDescription,
    String? jobTitle,
    String? companyName,
    String language = 'fr',
    CancelToken? cancelToken,
  }) async* {
    final formData = FormData.fromMap({
      'cv_file': await MultipartFile.fromFile(
        cvPath,
        contentType: MediaType('application', 'pdf'),
      ),
      'job_description': jobDescription,
      // ignore: use_null_aware_elements
      if (jobTitle != null) 'job_title': jobTitle,
      // ignore: use_null_aware_elements
      if (companyName != null) 'company_name': companyName,
      'language': language,
    });

    final response = await _dio.post(
      '/assistant/coach/analyze',
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

  /// Historique des sessions coach.
  Future<List<Map<String, dynamic>>> getHistory() async {
    final response = await _dio.get('/assistant/coach/history');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// Détail complet d'une session.
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _dio.get('/assistant/coach/$sessionId');
    return response.data as Map<String, dynamic>;
  }

  /// Supprimer une session.
  Future<void> deleteSession(String sessionId) async {
    await _dio.delete('/assistant/coach/$sessionId');
  }

  /// Supprimer toutes les sessions.
  Future<int> deleteAll() async {
    final response = await _dio.delete('/assistant/coach');
    return response.data['count'] as int? ?? 0;
  }

  /// Usage restant cette semaine.
  Future<Map<String, dynamic>> getUsage() async {
    final response = await _dio.get('/assistant/coach/usage');
    return response.data as Map<String, dynamic>;
  }
}
