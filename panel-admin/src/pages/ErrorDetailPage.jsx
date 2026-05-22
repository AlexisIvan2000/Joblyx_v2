import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, ExternalLink, User } from 'lucide-react';
import { getSentryIssueDetail, getSentryIssueEvents } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import LoadingSpinner from '../components/LoadingSpinner';
import Badge from '../components/Badge';
import { formatDateTime } from '../utils/format';
import '../styles/pages/errors.css';

function levelBadgeVariant(level) {
  if (level === 'fatal' || level === 'error') return 'danger';
  if (level === 'warning') return 'warning';
  if (level === 'info') return 'primary';
  return 'default';
}

function findTag(tags, key) {
  if (!tags || !Array.isArray(tags)) return null;
  const tag = tags.find((t) => t.key === key);
  return tag?.value || null;
}

function extractStackTrace(event) {
  // Sentry retourne les entries sous différents formats — on essaye d'extraire le stack le plus utile
  if (!event?.entries) return null;
  for (const entry of event.entries) {
    if (entry.type === 'exception') {
      const exc = entry.data?.values?.[0];
      if (exc?.stacktrace?.frames) {
        return exc.stacktrace.frames
          .slice()
          .reverse()
          .slice(0, 15)
          .map((f) => `  at ${f.function || '?'} (${f.filename || '?'}:${f.lineno || '?'})`)
          .join('\n');
      }
    }
  }
  return null;
}

export default function ErrorDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [issue, setIssue] = useState(null);
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    setError(null);

    Promise.all([
      getSentryIssueDetail(id),
      getSentryIssueEvents(id, 5),
    ])
      .then(([detail, eventList]) => {
        if (cancelled) return;
        setIssue(detail);
        setEvents(eventList || []);
      })
      .catch((err) => { if (!cancelled) setError(getErrorMessage(err)); })
      .finally(() => { if (!cancelled) setIsLoading(false); });

    return () => { cancelled = true; };
  }, [id]);

  if (isLoading) return <LoadingSpinner label="Chargement de l'erreur…" />;
  if (error) {
    return (
      <div>
        <button type="button" className="error-detail-back" onClick={() => navigate('/errors')}>
          <ArrowLeft size={16} strokeWidth={2.25} /> Retour
        </button>
        <div className="dashboard-error">{error}</div>
      </div>
    );
  }
  if (!issue) return null;

  const latestEvent = events[0];
  const tags = latestEvent?.tags || [];

  // Sentry préfixe le tag `user` par `id:`, `email:`, `username:`, etc.
  // On préfère event.user.id (UUID brut) et on strip le préfixe en fallback
  const rawUserId = latestEvent?.user?.id || findTag(tags, 'user');
  const userId = rawUserId?.startsWith('id:') ? rawUserId.slice(3) : rawUserId;
  const userEmail = latestEvent?.user?.email;
  const userRole = latestEvent?.user?.data?.role;

  return (
    <div>
      <button type="button" className="error-detail-back" onClick={() => navigate('/errors')}>
        <ArrowLeft size={16} strokeWidth={2.25} /> Retour aux erreurs
      </button>

      {/* En-tête */}
      <section className="error-detail-section">
        <h2 className="error-detail-title">
          {issue.metadata?.type || issue.title}
          {issue.metadata?.value && (
            <span className="muted"> · {issue.metadata.value}</span>
          )}
        </h2>

        <div className="error-detail-meta">
          <Badge variant={levelBadgeVariant(issue.level)}>{issue.level || 'event'}</Badge>
          <Badge variant="default">{issue.status || 'unresolved'}</Badge>
          {issue.environment && <Badge variant="primary">{issue.environment}</Badge>}
        </div>

        <div className="user-detail-list">
          <div className="error-detail-row">
            <span className="error-detail-row-label">Culprit</span>
            <span className="error-detail-row-value">{issue.culprit || '—'}</span>
          </div>
          <div className="error-detail-row">
            <span className="error-detail-row-label">Vue pour la première fois</span>
            <span className="error-detail-row-value">{formatDateTime(issue.firstSeen)}</span>
          </div>
          <div className="error-detail-row">
            <span className="error-detail-row-label">Dernière occurrence</span>
            <span className="error-detail-row-value">{formatDateTime(issue.lastSeen)}</span>
          </div>
          <div className="error-detail-row">
            <span className="error-detail-row-label">Occurrences</span>
            <span className="error-detail-row-value">{issue.count || 0} events · {issue.userCount || 0} users</span>
          </div>
          {issue.permalink && (
            <div className="error-detail-row">
              <span className="error-detail-row-label">Sentry</span>
              <a
                href={issue.permalink}
                target="_blank"
                rel="noreferrer"
                className="error-detail-user-link"
              >
                Ouvrir sur Sentry <ExternalLink size={14} strokeWidth={2.25} />
              </a>
            </div>
          )}
        </div>
      </section>

      {/* Utilisateur lié */}
      {(userId || userEmail) && (
        <section className="error-detail-section">
          <h3>Utilisateur concerné</h3>
          <div className="user-detail-list">
            {userEmail && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">Email</span>
                <span className="error-detail-row-value">{userEmail}</span>
              </div>
            )}
            {userId && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">ID</span>
                <span className="error-detail-row-value">{userId}</span>
              </div>
            )}
            {userRole && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">Rôle</span>
                <span className="error-detail-row-value">{userRole}</span>
              </div>
            )}
            {userId && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">Profil admin</span>
                <button
                  type="button"
                  className="error-detail-user-link"
                  onClick={() => navigate(`/users/${userId}`)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer' }}
                >
                  Voir l'utilisateur <User size={14} strokeWidth={2.25} />
                </button>
              </div>
            )}
          </div>
        </section>
      )}

      {/* Stack trace */}
      {latestEvent && (
        <section className="error-detail-section">
          <h3>Stack trace (dernier event)</h3>
          {(() => {
            const trace = extractStackTrace(latestEvent);
            if (!trace) return <div className="muted">Pas de stack trace disponible</div>;
            return <pre className="error-traceback">{trace}</pre>;
          })()}
        </section>
      )}

      {/* Contexte requête */}
      {latestEvent?.request && (
        <section className="error-detail-section">
          <h3>Requête</h3>
          <div className="user-detail-list">
            {latestEvent.request.method && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">Méthode</span>
                <span className="error-detail-row-value">{latestEvent.request.method}</span>
              </div>
            )}
            {latestEvent.request.url && (
              <div className="error-detail-row">
                <span className="error-detail-row-label">URL</span>
                <span className="error-detail-row-value">{latestEvent.request.url}</span>
              </div>
            )}
          </div>
        </section>
      )}

      {/* Tags */}
      {tags.length > 0 && (
        <section className="error-detail-section">
          <h3>Tags</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-xs)' }}>
            {tags.slice(0, 15).map((t, i) => (
              <Badge key={i} variant="default">
                {t.key} : {t.value}
              </Badge>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
