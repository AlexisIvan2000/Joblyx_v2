import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './AuthContext';

export function ProtectedRoute({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100vh',
        color: 'var(--color-text-muted)',
      }}>
        Chargement…
      </div>
    );
  }

  if (!isAuthenticated) {
    // On garde l'URL d'origine pour rediriger après login
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }

  return children;
}
