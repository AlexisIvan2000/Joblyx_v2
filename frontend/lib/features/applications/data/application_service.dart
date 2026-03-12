import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class ApplicationService {
  final Dio _dio = ApiClient().dio;

  Future<List<dynamic>> getAll({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _dio.get('/applications', queryParameters: params);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _dio.get('/applications/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, {
    String? cvPath,
    String? cvFilename,
  }) async {
    final map = <String, dynamic>{'data': jsonEncode(data)};
    if (cvPath != null) {
      map['cv'] = await MultipartFile.fromFile(
        cvPath,
        filename: cvFilename ?? 'cv.pdf',
      );
    }
    final formData = FormData.fromMap(map);
    final response = await _dio.post('/applications', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/applications/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _dio.delete('/applications/$id');
  }
}
