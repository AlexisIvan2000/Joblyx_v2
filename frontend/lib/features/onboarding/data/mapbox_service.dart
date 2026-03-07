import 'dart:async';
import 'package:dio/dio.dart';

/// Service d'autocomplétion de lieux via Mapbox Geocoding API (Canada uniquement)
class MapboxService {
  static const _token =
      'pk.eyJ1IjoiYWxleGl2YW4yMCIsImEiOiJjbWZnenhvbXEwNmxoMmxvb212MDF5YjhqIn0.2vzQCga4QIRBlv_zrZCHqg';

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.mapbox.com/geocoding/v5/mapbox.places',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Timer? _debounce;

  /// Recherche de lieux avec debounce (400ms)
  Future<List<MapboxPlace>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];

    final completer = Completer<List<MapboxPlace>>();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final response = await _dio.get(
          '/${Uri.encodeComponent(query.trim())}.json',
          queryParameters: {
            'access_token': _token,
            'country': 'ca',
            'types': 'place',
            'limit': 5,
            'language': 'fr,en',
          },
        );

        final features = response.data['features'] as List;
        final places = features.map((f) => MapboxPlace.fromJson(f)).toList();
        completer.complete(places);
      } catch (_) {
        completer.complete([]);
      }
    });

    return completer.future;
  }

  void dispose() {
    _debounce?.cancel();
  }
}

class MapboxPlace {
  final String city;
  final String province;
  final String fullName;

  MapboxPlace({required this.city, required this.province, required this.fullName});

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final placeName = json['place_name'] as String? ?? '';
    final text = json['text'] as String? ?? '';

    // Extraire la province depuis le contexte
    String province = '';
    final context = json['context'] as List? ?? [];
    for (final ctx in context) {
      final id = ctx['id'] as String? ?? '';
      if (id.startsWith('region')) {
        province = ctx['short_code'] as String? ?? ctx['text'] as String? ?? '';
        // Retirer le préfixe "CA-" si présent (ex: "CA-QC" → "QC")
        if (province.startsWith('CA-')) {
          province = province.substring(3);
        }
        break;
      }
    }

    return MapboxPlace(
      city: text,
      province: province,
      fullName: placeName,
    );
  }
}
