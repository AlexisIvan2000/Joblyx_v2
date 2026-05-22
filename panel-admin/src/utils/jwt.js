// Decode un JWT sans vérifier la signature — utilisé uniquement pour extraire role/exp côté client
// La sécurité est assurée par le backend qui valide à chaque requête

export function decodeJwt(token) {
  if (!token) return null;
  try {
    const payload = token.split('.')[1];
    if (!payload) return null;
    const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}

export function isExpired(token) {
  const payload = decodeJwt(token);
  if (!payload || !payload.exp) return true;
  return Date.now() >= payload.exp * 1000;
}

export function getRole(token) {
  const payload = decodeJwt(token);
  return payload?.role || 'user';
}

export function isAdmin(token) {
  const role = getRole(token);
  return role === 'admin' || role === 'super_admin';
}
