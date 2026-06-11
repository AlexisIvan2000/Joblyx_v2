import { apiClient } from './client';

// Dashboard stats

export async function getStats() {
  const { data } = await apiClient.get('/admin/stats');
  return data;
}

export async function getRegistrations(period = 'week') {
  const { data } = await apiClient.get('/admin/stats/registrations', {
    params: { period },
  });
  return data;
}

// Users CRUD

export async function listUsers({ search, page = 1, limit = 20, isActive, verified, role } = {}) {
  const params = { page, limit };
  if (search) params.search = search;
  if (isActive !== undefined && isActive !== null) params.is_active = isActive;
  if (verified !== undefined && verified !== null) params.verified = verified;
  if (role) params.role = role;

  const { data } = await apiClient.get('/admin/users', { params });
  return data;
}

export async function getUserDetail(userId) {
  const { data } = await apiClient.get(`/admin/users/${userId}`);
  return data;
}

export async function setUserStatus(userId, { isActive, reason }) {
  const { data } = await apiClient.patch(`/admin/users/${userId}/status`, {
    is_active: isActive,
    reason,
  });
  return data;
}

export async function resetUserLimits(userId) {
  const { data } = await apiClient.patch(`/admin/users/${userId}/reset-limits`);
  return data;
}

export async function updateUserRole(userId, role) {
  const { data } = await apiClient.patch(`/admin/users/${userId}/role`, { role });
  return data;
}

export async function updateUserNotes(userId, notes) {
  const { data } = await apiClient.patch(`/admin/users/${userId}/notes`, { notes });
  return data;
}

export async function sendEmailToUser(userId, { subject, body }) {
  const { data } = await apiClient.post(`/admin/users/${userId}/email`, { subject, body });
  return data;
}

export async function deleteUser(userId) {
  const { data } = await apiClient.delete(`/admin/users/${userId}`);
  return data;
}

// Audit log

export async function getAuditLog({ page = 1, limit = 50, action, targetId, search } = {}) {
  const params = { page, limit };
  if (action) params.action = action;
  if (targetId) params.target_id = targetId;
  if (search) params.search = search;

  const { data } = await apiClient.get('/admin/audit-log', { params });
  return data;
}

// Sentry — proxied via le backend (le token Sentry ne quitte jamais le serveur)

export async function listSentryIssues({ query = 'is:unresolved', cursor, limit = 25, environment } = {}) {
  const params = { query, limit };
  if (cursor) params.cursor = cursor;
  if (environment) params.environment = environment;

  const { data } = await apiClient.get('/admin/sentry/issues', { params });
  return data;
}

export async function getSentryIssueDetail(issueId) {
  const { data } = await apiClient.get(`/admin/sentry/issues/${issueId}`);
  return data;
}

export async function getSentryIssueEvents(issueId, limit = 10) {
  const { data } = await apiClient.get(`/admin/sentry/issues/${issueId}/events`, {
    params: { limit },
  });
  return data;
}
