class AuthFailure {
  final String key;
  final int? statusCode;

  const AuthFailure(this.key, {this.statusCode});

  /// Backend `detail` string → i18n key.
  static const _map = {
    // Register
    'Email already registered': 'auth_error.email_already_registered',

    // Login
    'Invalid email or password': 'auth_error.invalid_credentials',
    'Please verify your email before logging in': 'auth_error.email_not_verified',

    // Verify email
    'Invalid verification request': 'auth_error.invalid_verification_request',
    'Invalid verification code': 'auth_error.invalid_code',
    'Verification code expired. Please request a new one.': 'auth_error.code_expired',

    // Brute-force / rate limit
    'Too many attempts, request a new code': 'auth_error.too_many_attempts',
    'Too many code requests, please try again later': 'auth_error.rate_limited',

    // Reset password
    'Invalid or expired reset code': 'auth_error.invalid_or_expired_code',
    'Invalid reset code': 'auth_error.invalid_code',
    'Reset code has expired': 'auth_error.code_expired',

    // Email change
    'No pending email change': 'auth_error.no_pending_email_change',
    'No email change code found': 'auth_error.no_email_change_code',
    'Email already in use': 'auth_error.email_already_in_use',

    // Password
    'Current password is incorrect': 'auth_error.wrong_current_password',
    'New password must be different from current password': 'auth_error.same_password',
    'Invalid password': 'auth_error.invalid_password',

    // Refresh token / session
    'Invalid or expired refresh token': 'auth_error.session_expired',

    // LinkedIn
    'This account uses LinkedIn sign-in': 'auth_error.linkedin_account',
    'Failed to authenticate with LinkedIn': 'auth_error.linkedin_failed',
    'LinkedIn account has no email address': 'auth_error.linkedin_no_email',

    // Other
    'User not found': 'auth_error.user_not_found',
    'No fields to update': 'auth_error.no_fields_to_update',
  };

  /// Fallback by HTTP status code.
  static const _statusFallback = {
    400: 'auth_error.bad_request',
    401: 'auth_error.unauthorized',
    403: 'auth_error.forbidden',
    429: 'auth_error.too_many_attempts',
    500: 'auth_error.server_error',
  };

  /// Resolves a backend detail + statusCode into an i18n key.
  static String resolve(String? detail, {int? statusCode}) {
    if (detail != null && _map.containsKey(detail)) {
      return _map[detail]!;
    }
    if (statusCode != null && _statusFallback.containsKey(statusCode)) {
      return _statusFallback[statusCode]!;
    }
    return 'auth_error.unknown';
  }
}
