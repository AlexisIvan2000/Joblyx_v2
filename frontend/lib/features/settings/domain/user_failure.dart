class UserFailure {
  // Backend `error` code vers clé i18n, prioritaire sur le texte
  static const _codeMap = {
    'weak_password': 'settings_error.weak_password',
    'password_too_short': 'settings_error.password_too_short',
    'password_too_long': 'settings_error.password_too_long',
    'password_missing_uppercase': 'settings_error.password_missing_uppercase',
    'password_missing_lowercase': 'settings_error.password_missing_lowercase',
    'password_missing_special': 'settings_error.password_missing_special',
  };

  static const _map = {
    'Current password is incorrect': 'settings_error.wrong_password',
    'Invalid password': 'settings_error.invalid_password',
    'Email already in use': 'settings_error.email_taken',
    'No pending email change': 'settings_error.no_pending_change',
    'No email change code found': 'settings_error.no_change_code',
    'Invalid verification code': 'settings_error.invalid_code',
    'Verification code expired. Please request a new one.': 'settings_error.code_expired',
    'Too many attempts, request a new code': 'settings_error.too_many_attempts',
    'Too many code requests, please try again later': 'settings_error.rate_limited',
    'No fields to update': 'settings_error.no_fields',
    'This account uses LinkedIn sign-in': 'settings_error.linkedin_account',
    'Account already has a password': 'settings_error.password_already_set',
    'Email does not match your account': 'settings_error.email_mismatch',
    'Your account has been banned': 'settings_error.account_banned',
  };

  static const _statusFallback = {
    400: 'settings_error.bad_request',
    401: 'settings_error.unauthorized',
    403: 'settings_error.forbidden',
    409: 'settings_error.conflict',
    429: 'settings_error.too_many_attempts',
    500: 'settings_error.server_error',
  };

  static String resolve(String? detail, {String? code, int? statusCode}) {
    if (code != null && _codeMap.containsKey(code)) {
      return _codeMap[code]!;
    }
    if (detail != null && _map.containsKey(detail)) {
      return _map[detail]!;
    }
    if (statusCode != null && _statusFallback.containsKey(statusCode)) {
      return _statusFallback[statusCode]!;
    }
    return 'settings_error.unknown';
  }
}
