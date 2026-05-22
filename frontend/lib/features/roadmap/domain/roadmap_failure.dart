class RoadmapFailure {
  static const _map = {
    'Profile not found': 'roadmap_error.profile_not_found',
    'No active roadmap': 'roadmap_error.no_active_roadmap',
    'No active roadmap to archive': 'roadmap_error.no_active_roadmap',
    'Roadmap not found': 'roadmap_error.roadmap_not_found',
    'Roadmap not found or not archived': 'roadmap_error.no_archived_roadmap',
    'Phase not found': 'roadmap_error.phase_not_found',
    'Action not found': 'roadmap_error.action_not_found',
    'Skill not found': 'roadmap_error.skill_not_found',
    'Career profile not found. Complete onboarding first.': 'roadmap_error.career_required',
    'phase_ids must match all phases of the active roadmap': 'roadmap_error.invalid_phase_ids',
    'Monthly regeneration limit reached (5 per month)': 'roadmap_error.regeneration_limit',
  };

  static const _statusFallback = {
    400: 'roadmap_error.bad_request',
    404: 'roadmap_error.not_found',
    429: 'roadmap_error.rate_limit',
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
