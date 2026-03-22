import 'dart:async';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:frontend/core/network/api_client.dart';

class InterviewService {
  final Dio _dio;

  InterviewService() : _dio = ApiClient().dio;
  InterviewService.withDio(this._dio);

  /// Démarre une nouvelle session d'entretien (multipart pour le CV optionnel).
  Future<Map<String, dynamic>> startSession({
    required String jobTitle,
    String? companyName,
    String? jobDescription,
    String? cvPath,
    String language = 'fr',
  }) async {
    final map = <String, dynamic>{
      'job_title': jobTitle,
      'language': language,
    };
    if (companyName != null) map['company_name'] = companyName;
    if (jobDescription != null) map['job_description'] = jobDescription;
    if (cvPath != null) {
      map['cv_file'] = await MultipartFile.fromFile(
        cvPath,
        contentType: MediaType('application', 'pdf'),
      );
    }
    final formData = FormData.fromMap(map);
    final response = await _dio.post('/assistant/interview/start', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Termine un entretien en avance.
  Future<Map<String, dynamic>> endSessionEarly(String sessionId) async {
    final response = await _dio.post('/assistant/interview/$sessionId/end');
    return response.data as Map<String, dynamic>;
  }

  /// Historique des sessions.
  Future<List<Map<String, dynamic>>> getHistory() async {
    final response = await _dio.get('/assistant/interview/history');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// Détail complet d'une session avec messages.
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final response = await _dio.get('/assistant/interview/$sessionId');
    return response.data as Map<String, dynamic>;
  }

  /// Bilan seul.
  Future<Map<String, dynamic>> getSummary(String sessionId) async {
    final response = await _dio.get('/assistant/interview/$sessionId/summary');
    return response.data as Map<String, dynamic>;
  }

  /// Usage restant aujourd'hui.
  Future<Map<String, dynamic>> getUsage() async {
    final response = await _dio.get('/assistant/interview/usage');
    return response.data as Map<String, dynamic>;
  }

  /// Supprimer une session.
  Future<void> deleteSession(String sessionId) async {
    await _dio.delete('/assistant/interview/$sessionId');
  }

  /// Supprimer toutes les sessions.
  Future<int> deleteAll() async {
    final response = await _dio.delete('/assistant/interview');
    return response.data['count'] as int? ?? 0;
  }

  /// Connecte un WebSocket pour le chat d'entretien.
  /// Le token JWT est passé en query param.
  WebSocketChannel connectWebSocket(String sessionId, String token) {
    // Extraire le baseUrl du Dio pour construire l'URL WS
    final baseUrl = _dio.options.baseUrl;
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/assistant/interview/ws/$sessionId?token=$token');
    return WebSocketChannel.connect(uri);
  }
}
