// Endpoints d'authentification login, logout, refresh, get_me

import { apiClient } from './client';
import { tokenStorage } from '../utils/storage';

export async function login({ email, password }) {
  const { data } = await apiClient.post('/auth/login', { email, password });
  tokenStorage.setTokens(data.access_token, data.refresh_token);
  return data;
}

export async function logout() {
  const refreshToken = tokenStorage.getRefresh();
  if (refreshToken) {
    try {
      await apiClient.post('/auth/logout', { refresh_token: refreshToken });
    } catch {
      // Ignore les erreurs de logout on purge quand même côté client
    }
  }
  tokenStorage.clear();
}

export async function getMe() {
  const { data } = await apiClient.get('/users/me');
  return data;
}
