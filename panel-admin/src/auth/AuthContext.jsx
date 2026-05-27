import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { login as apiLogin, logout as apiLogout, getMe } from '../api/auth';
import { tokenStorage } from '../utils/storage';
import { isAdmin as jwtIsAdmin, isExpired } from '../utils/jwt';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // Au mount, on tente de restaurer la session si un token est présent
  useEffect(() => {
    const token = tokenStorage.getAccess();
    if (!token) {
      setIsLoading(false);
      return;
    }
    if (!jwtIsAdmin(token)) {
      // Token valide mais pas admin  on purge pour forcer un nouveau login
      tokenStorage.clear();
      setIsLoading(false);
      return;
    }
    // Session morte (access ET refresh expirés) : on purge sans appeler le backend
    if (isExpired(token) && isExpired(tokenStorage.getRefresh())) {
      tokenStorage.clear();
      setIsLoading(false);
      return;
    }
    // Le token semble bon, on récupère le user actuel
    getMe()
      .then((me) => setUser(me))
      .catch(() => tokenStorage.clear())
      .finally(() => setIsLoading(false));
  }, []);

  const login = useCallback(async (email, password) => {
    const tokens = await apiLogin({ email, password });
    if (!jwtIsAdmin(tokens.access_token)) {
      // Le compte existe mais n'a pas le rôle admin  on bloque côté client
      tokenStorage.clear();
      const err = new Error('Admin privileges required');
      err.code = 'not_admin';
      throw err;
    }
    const me = await getMe();
    setUser(me);
    return me;
  }, []);

  const logout = useCallback(async () => {
    await apiLogout();
    setUser(null);
  }, []);

  const value = {
    user,
    isAuthenticated: user !== null,
    isLoading,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}
