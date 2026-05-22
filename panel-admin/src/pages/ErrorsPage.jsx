import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AlertTriangle, ExternalLink } from 'lucide-react';
import { listSentryIssues } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import LoadingSpinner from '../components/LoadingSpinner';
import Badge from '../components/Badge';
import { formatDateTime } from '../utils/format';
import '../styles/pages/errors.css';
import '../styles/components/form.css';

const FILTERS = [
  { label: 'Non résolues', value: 'is:unresolved' },
  { label: 'Résolues', value: 'is:resolved' },
  { label: 'Ignorées', value: 'is:ignored' },
  { label: 'Toutes', value: '' },
];

function levelBadgeVariant(level) {
  if (level === 'fatal' || level === 'error') return 'danger';
  if (level === 'warning') return 'warning';
  if (level === 'info') return 'primary';
  return 'default';
}

export default function ErrorsPage() {
  const navigate = useNavigate();
  const [query, setQuery] = useState('is:unresolved');
  const [environment, setEnvironment] = useState('');
  const [issues, setIssues] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isConfigured, setIsConfigured] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    setError(null);

    listSentryIssues({
      query: query || undefined,
      environment: environment || undefined,
      limit: 25,
    })
      .then((data) => {
        if (cancelled) return;
        setIssues(data.issues || []);
        setNextCursor(data.next_cursor);
      })
      .catch((err) => {
        if (cancelled) return;
        // Backend renvoie 503 sentry_not_configured si SENTRY_API_TOKEN absent
        if (err?.response?.data?.error === 'sentry_not_configured') {
          setIsConfigured(false);
        } else {
          setError(getErrorMessage(err));
        }
      })
      .finally(() => { if (!cancelled) setIsLoading(false); });

    return () => { cancelled = true; };
  }, [query, environment]);

  if (!isConfigured) {
    return (
      <div className="errors-not-configured">
        <strong>Sentry n'est pas configuré sur ce backend.</strong>
        <br />
        Pour activer cette page, ajoute les variables d'env suivantes côté backend (Railway / .env) :
        <ul style={{ marginTop: '0.5rem', paddingLeft: '1.25rem' }}>
          <li><code className="mono">SENTRY_API_TOKEN</code> — Auth Token Sentry avec scopes <code className="mono">issue:read event:read</code></li>
          <li><code className="mono">SENTRY_ORG_SLUG</code> — slug de ton organisation (ex: <code className="mono">joblyx</code>)</li>
          <li><code className="mono">SENTRY_PROJECT_SLUG</code> — slug du projet (ex: <code className="mono">joblyx-backend</code>)</li>
        </ul>
        <div style={{ marginTop: '0.75rem' }}>
          Crée le token sur{' '}
          <a href="https://sentry.io/settings/account/api/auth-tokens/" target="_blank" rel="noreferrer" style={{ color: 'var(--color-primary)', fontWeight: 600 }}>
            sentry.io/settings/account/api/auth-tokens
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="errors-page">
      <div className="toolbar">
        <select className="filter-select" value={query} onChange={(e) => setQuery(e.target.value)}>
          {FILTERS.map((f) => (
            <option key={f.value} value={f.value}>{f.label}</option>
          ))}
        </select>
        <select className="filter-select" value={environment} onChange={(e) => setEnvironment(e.target.value)}>
          <option value="">Tous les environnements</option>
          <option value="production">Production</option>
          <option value="staging">Staging</option>
          <option value="development">Development</option>
        </select>
      </div>

      {error && (
        <div className="dashboard-error">{error}</div>
      )}

      {isLoading ? (
        <LoadingSpinner label="Chargement des erreurs Sentry…" />
      ) : issues.length === 0 ? (
        <div style={{
          textAlign: 'center',
          padding: 'var(--space-2xl)',
          color: 'var(--color-text-muted)',
          background: 'var(--color-surface)',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-lg)',
        }}>
          <AlertTriangle size={28} style={{ margin: '0 auto var(--space-sm)', display: 'block', opacity: 0.5 }} />
          Aucune erreur sur la période
        </div>
      ) : (
        <div className="errors-list">
          {issues.map((issue) => (
            <button
              key={issue.id}
              type="button"
              className="error-issue-card"
              onClick={() => navigate(`/errors/${issue.id}`)}
            >
              <div className={`error-issue-level ${issue.level || ''}`} />
              <div className="error-issue-body">
                <div className="error-issue-title">
                  {issue.metadata?.type || issue.title}
                  {issue.metadata?.value && (
                    <span className="muted"> · {issue.metadata.value}</span>
                  )}
                </div>
                <div className="error-issue-meta">
                  {issue.culprit || issue.shortId} · vu {formatDateTime(issue.lastSeen)}
                </div>
              </div>
              <div className="error-issue-stats">
                <Badge variant={levelBadgeVariant(issue.level)}>
                  {issue.level || 'event'}
                </Badge>
                <div className="error-issue-stat">
                  <span className="error-issue-stat-value">{issue.count || 0}</span>
                  <span className="error-issue-stat-label">events</span>
                </div>
                <div className="error-issue-stat">
                  <span className="error-issue-stat-value">{issue.userCount || 0}</span>
                  <span className="error-issue-stat-label">users</span>
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
