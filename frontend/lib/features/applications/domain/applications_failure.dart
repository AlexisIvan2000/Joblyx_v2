class ApplicationsFailure {
  static const _map = {
    'Application not found': 'applications_error.not_found',
    'No fields to update': 'applications_error.no_fields_to_update',
    'No CV attached to this application': 'applications_error.no_cv',
    'Only PDF files are accepted': 'applications_error.only_pdf',
    'File too large (max 5 MB)': 'applications_error.file_too_large',
  };

  static const _statusFallback = {
    400: 'applications_error.bad_request',
    404: 'applications_error.not_found',
    500: 'applications_error.server_error',
  };

  static String resolve(String? detail, {int? statusCode}) {
    if (detail != null && _map.containsKey(detail)) {
      return _map[detail]!;
    }
    if (statusCode != null && _statusFallback.containsKey(statusCode)) {
      return _statusFallback[statusCode]!;
    }
    return 'applications_error.unknown';
  }
}
