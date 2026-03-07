class OnboardingFailure {
  static const _map = {
    'Profile already completed': 'onboarding_error.already_completed',
    'Profile not found': 'onboarding_error.not_found',
  };

  static const _statusFallback = {
    400: 'onboarding_error.bad_request',
    409: 'onboarding_error.already_completed',
    500: 'onboarding_error.server_error',
  };

  static String resolve(String? detail, {int? statusCode}) {
    if (detail != null && _map.containsKey(detail)) {
      return _map[detail]!;
    }
    if (statusCode != null && _statusFallback.containsKey(statusCode)) {
      return _statusFallback[statusCode]!;
    }
    return 'onboarding_error.unknown';
  }
}
