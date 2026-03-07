class RoadmapFailure {
  static const _map = {
    'Profile not found': 'roadmap_error.profile_not_found',
    'No active roadmap': 'roadmap_error.no_active_roadmap',
  };

  static const _statusFallback = {
    404: 'roadmap_error.not_found',
    500: 'roadmap_error.server_error',
  };

  static String resolve(String? detail, {int? statusCode}) {
    if (detail != null && _map.containsKey(detail)) {
      return _map[detail]!;
    }
    if (statusCode != null && _statusFallback.containsKey(statusCode)) {
      return _statusFallback[statusCode]!;
    }
    return 'roadmap_error.unknown';
  }
}
