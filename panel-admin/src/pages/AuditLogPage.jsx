import { useEffect, useState } from 'react';
import DataTable from '../components/DataTable';
import Pagination from '../components/Pagination';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';
import SearchInput from '../components/SearchInput';
import { getAuditLog } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import { formatDateTime } from '../utils/format';
import '../styles/components/form.css';

const PAGE_SIZE = 50;

const ACTION_LABELS = {
  'user.activate': 'Activation',
  'user.deactivate': 'Désactivation',
  'user.reset_limits': 'Reset limites',
  'user.delete': 'Suppression',
  'user.role.change': 'Changement de rôle',
  'user.notes.update': 'Notes admin',
  'user.ban': 'Bannissement',
  'user.unban': 'Débannissement',
};

const ACTION_VARIANTS = {
  'user.activate': 'success',
  'user.deactivate': 'danger',
  'user.reset_limits': 'warning',
  'user.delete': 'danger',
  'user.role.change': 'primary',
  'user.notes.update': 'default',
  'user.ban': 'danger',
  'user.unban': 'success',
};

function actionLabel(action) {
  return ACTION_LABELS[action] || action;
}

function actionVariant(action) {
  return ACTION_VARIANTS[action] || 'default';
}

function renderTarget(entry) {
  const email = entry.payload?.target_email;
  if (email) return <span style={{ fontWeight: 500 }}>{email}</span>;
  if (entry.target_id) {
    return <span className="mono text-xs muted">{entry.target_id.slice(0, 8)}…</span>;
  }
  return <span className="muted">—</span>;
}

function renderPayload(entry) {
  const p = entry.payload || {};
  const parts = [];
  if (p.reason) parts.push(`Raison : ${p.reason}`);
  if (p.previous_role && p.new_role) parts.push(`${p.previous_role} → ${p.new_role}`);
  if (p.target_role && entry.action === 'user.delete') parts.push(`Rôle : ${p.target_role}`);
  if (parts.length === 0) return <span className="muted">—</span>;
  return <span className="text-xs">{parts.join(' · ')}</span>;
}

const COLUMNS = [
  {
    key: 'created_at',
    label: 'Date',
    render: (e) => <span className="text-xs muted">{formatDateTime(e.created_at)}</span>,
  },
  {
    key: 'action',
    label: 'Action',
    render: (e) => <Badge variant={actionVariant(e.action)}>{actionLabel(e.action)}</Badge>,
  },
  {
    key: 'target',
    label: 'Cible',
    render: renderTarget,
  },
  {
    key: 'details',
    label: 'Détails',
    render: renderPayload,
  },
];

export default function AuditLogPage() {
  const [actionFilter, setActionFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [page, setPage] = useState(1);
  const [data, setData] = useState({ entries: [], total: 0 });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Debounce recherche (350ms)
  useEffect(() => {
    const id = setTimeout(() => setDebouncedSearch(search.trim()), 350);
    return () => clearTimeout(id);
  }, [search]);

  // Reset page sur changement de filtre ou de recherche
  useEffect(() => {
    setPage(1);
  }, [actionFilter, debouncedSearch]);

  // Fetch des logs
  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    setError(null);

    const params = {
      page, limit: PAGE_SIZE,
      action: actionFilter === 'all' ? undefined : actionFilter,
      search: debouncedSearch || undefined,
    };

    getAuditLog(params)
      .then((result) => { if (!cancelled) setData({ entries: result.entries, total: result.total }); })
      .catch((err) => { if (!cancelled) setError(getErrorMessage(err)); })
      .finally(() => { if (!cancelled) setIsLoading(false); });

    return () => { cancelled = true; };
  }, [actionFilter, debouncedSearch, page]);

  return (
    <div>
      <div className="toolbar">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder="Rechercher par email cible…"
        />
        <select
          className="filter-select"
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
        >
          <option value="all">Toutes les actions</option>
          <option value="user.deactivate">Désactivations</option>
          <option value="user.activate">Activations</option>
          <option value="user.reset_limits">Reset limites</option>
          <option value="user.delete">Suppressions</option>
          <option value="user.role.change">Changements de rôle</option>
          <option value="user.notes.update">Notes admin</option>
        </select>
      </div>

      {error && (
        <div style={{
          padding: 'var(--space-md)',
          backgroundColor: 'var(--color-danger-bg)',
          color: 'var(--color-danger-hover)',
          borderRadius: 'var(--radius)',
          borderLeft: '3px solid var(--color-danger)',
          marginBottom: 'var(--space-md)',
        }}>
          {error}
        </div>
      )}

      {isLoading ? (
        <LoadingSpinner label="Chargement de l'historique…" />
      ) : (
        <>
          <DataTable
            columns={COLUMNS}
            rows={data.entries}
            emptyMessage="Aucune action enregistrée"
          />
          <div style={{ marginTop: 'var(--space-md)' }}>
            <div className="data-table-wrapper">
              <Pagination
                page={page}
                pageSize={PAGE_SIZE}
                total={data.total}
                onChange={setPage}
              />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
