export function parseApiError(axiosError) {
  const response = axiosError?.response;
  const data = response?.data;

  // Format normalisé du nouveau backend
  if (data && typeof data === 'object') {
    return {
      error: data.error || 'unknown',
      message: data.message || data.detail || 'An error occurred',
      details: data.details || {},
      statusCode: response?.status,
    };
  }

  // Fallback : erreur réseau ou format inattendu
  return {
    error: 'network_error',
    message: axiosError?.message || 'Network error',
    details: {},
    statusCode: response?.status,
  };
}

export function getErrorMessage(axiosError) {
  return parseApiError(axiosError).message;
}
