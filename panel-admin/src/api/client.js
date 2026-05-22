// Instance axios partagée avec intercepteurs JWT et auto-refresh sur 401

import axios from 'axios';
import { tokenStorage } from '../utils/storage';

const BASE_URL = import.meta.env.VITE_API_URL || 'https://api.joblyx.com';
const API_PREFIX = '/v1';

export const apiClient = axios.create({
  baseURL: `${BASE_URL}${API_PREFIX}`,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor  ajoute Authorization sur chaque requête sortante
apiClient.interceptors.request.use((config) => {
  const token = tokenStorage.getAccess();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Évite les boucles infinies pendant le refresh
let isRefreshing = false;
let pendingRequests = [];

function onTokenRefreshed(newAccessToken) {
  pendingRequests.forEach((cb) => cb(newAccessToken));
  pendingRequests = [];
}

function queueRequest(callback) {
  return new Promise((resolve) => {
    pendingRequests.push((newToken) => {
      callback(newToken);
      resolve();
    });
  });
}

// Response interceptor  auto-refresh sur 401
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const isAuthRoute = originalRequest?.url?.includes('/auth/');

    // Pas de retry si 401 sur /auth/refresh lui-même ou si déjà retry
    if (error.response?.status !== 401 || isAuthRoute || originalRequest._retry) {
      return Promise.reject(error);
    }

    originalRequest._retry = true;

    if (isRefreshing) {
      // Une requête refresh est déjà en cours on attend qu'elle finisse
      await queueRequest((newToken) => {
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
      });
      return apiClient(originalRequest);
    }

    isRefreshing = true;
    try {
      const refreshToken = tokenStorage.getRefresh();
      if (!refreshToken) throw new Error('No refresh token');

      const { data } = await axios.post(`${BASE_URL}${API_PREFIX}/auth/refresh`, {
        refresh_token: refreshToken,
      });

      tokenStorage.setTokens(data.access_token, data.refresh_token);
      onTokenRefreshed(data.access_token);
      originalRequest.headers.Authorization = `Bearer ${data.access_token}`;
      return apiClient(originalRequest);
    } catch (refreshError) {
      // Refresh impossible  on purge et le ProtectedRoute redirigera vers /login
      tokenStorage.clear();
      pendingRequests = [];
      window.location.href = '/login';
      return Promise.reject(refreshError);
    } finally {
      isRefreshing = false;
    }
  },
);
