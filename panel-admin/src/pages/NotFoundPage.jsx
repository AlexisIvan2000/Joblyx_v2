import { useNavigate } from 'react-router-dom';
import { AlertTriangle } from 'lucide-react';
import '../styles/components/button.css';

// Page 404 publique affichée pour toute route inconnue du panel
export default function NotFoundPage() {
  const navigate = useNavigate();

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '12px',
        minHeight: '100vh',
        padding: '24px',
        textAlign: 'center',
        color: 'var(--color-text)',
      }}
    >
      <AlertTriangle size={48} strokeWidth={1.75} style={{ color: 'var(--color-primary)' }} />
      <div style={{ fontSize: '64px', fontWeight: 800, lineHeight: 1, color: 'var(--color-primary)' }}>
        404
      </div>
      <h1 style={{ fontSize: '20px', margin: 0 }}>Page introuvable</h1>
      <p style={{ color: 'var(--color-text-muted)', margin: 0, maxWidth: 420 }}>
        La page que tu cherches n'existe pas ou a été déplacée.
      </p>
      <button
        type="button"
        className="btn btn-primary"
        style={{ marginTop: '8px' }}
        onClick={() => navigate('/login')}
      >
        Retour à la connexion
      </button>
    </div>
  );
}
