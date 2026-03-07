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
}
