import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import DataTable from '../components/DataTable';
import Pagination from '../components/Pagination';
import SearchInput from '../components/SearchInput';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';
import LiveIndicator from '../components/LiveIndicator';
import { listUsers } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import { formatDateTime } from '../utils/format';
import { usePoll } from '../hooks/usePoll';
import '../styles/components/form.css';
import '../styles/components/live-indicator.css';

const PAGE_SIZE = 20;

function roleLabel(role) {
  if (role === 'super_admin') return 'Super admin';
  if (role === 'admin') return 'Admin';
  return 'User';
}

function roleVariant(role) {
  if (role === 'super_admin') return 'primary';
  if (role === 'admin') return 'warning';
  return 'default';
}

const COLUMNS = [
  {
    key: 'name',
    label: 'Nom',
    render: (u) => (
      <div>
        <div style={{ fontWeight: 500 }}>{u.first_name} {u.last_name}</div>
        <div className="muted text-xs">{u.email}</div>
      </div>
    ),
  },
  {
    key: 'role',
    label: 'Rôle',
    render: (u) => <Badge variant={roleVariant(u.role)}>{roleLabel(u.role)}</Badge>,
  },
  {
    key: 'status',
    label: 'Statut',
    render: (u) => (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <Badge variant={u.is_active ? 'success' : 'danger'} withDot>
          {u.is_active ? 'Actif' : 'Désactivé'}
        </Badge>
        {!u.is_verified && (
          <Badge variant="warning">Non vérifié</Badge>
        )}
      </div>
    ),
  },
  {
    key: 'auth',
    label: 'Auth',
    render: (u) => u.has_linkedin ? 'LinkedIn' : 'Email',
  },
  {
    key: 'counts',
    label: 'Activité',
    render: (u) => (
      <span className="muted text-xs">
        {u.roadmaps_count}r · {u.applications_count}c · {u.coach_sessions_count}coach · {u.interview_sessions_count}int
      </span>
    ),
  },
  {
    key: 'created',
    label: 'Inscrit',
    render: (u) => <span className="muted text-xs">{formatDateTime(u.created_at)}</span>,
  },
];

export default function UsersPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');   // all | active | inactive
  const [verifiedFilter, setVerifiedFilter] = useState('all'); // all | yes | no
  const [roleFilter, setRoleFilter] = useState('all');
  const [page, setPage] = useState(1);

  // Debounce de la recherche (350ms)
  useEffect(() => {
    const id = setTimeout(() => setDebouncedSearch(search.trim()), 350);
    return () => clearTimeout(id);
  }, [search]);

  // Reset page sur changement de filtres/search
  useEffect(() => {
    setPage(1);
  }, [debouncedSearch, statusFilter, verifiedFilter, roleFilter]);

  // Fetch des users avec polling auto (10s)
  const fetchUsers = useCallback(() => listUsers({
    page, limit: PAGE_SIZE,
    search: debouncedSearch || undefined,
    isActive: statusFilter === 'all' ? undefined : statusFilter === 'active',
    verified: verifiedFilter === 'all' ? undefined : verifiedFilter === 'yes',
    role: roleFilter === 'all' ? undefined : roleFilter,
  }), [page, debouncedSearch, statusFilter, verifiedFilter, roleFilter]);

  const { data: result, isLoading, error, lastUpdate, isRefreshing, refetch } = usePoll(
    fetchUsers,
    [page, debouncedSearch, statusFilter, verifiedFilter, roleFilter],
    { interval: 10000 },
  );

  const data = result || { users: [], total: 0 };
  const errorMessage = error ? getErrorMessage(error) : null;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 'var(--space-md)' }}>
        <LiveIndicator
          lastUpdate={lastUpdate}
          isRefreshing={isRefreshing}
          onRefresh={refetch}
        />
      </div>

      <div className="toolbar">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder="Rechercher par email, prénom ou nom…"
        />
        <select className="filter-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">Tous statuts</option>
          <option value="active">Actifs</option>
          <option value="inactive">Désactivés</option>
        </select>
        <select className="filter-select" value={verifiedFilter} onChange={(e) => setVerifiedFilter(e.target.value)}>
          <option value="all">Tous (vérif)</option>
          <option value="yes">Vérifiés</option>
          <option value="no">Non vérifiés</option>
        </select>
        <select className="filter-select" value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
          <option value="all">Tous rôles</option>
          <option value="user">User</option>
          <option value="admin">Admin</option>
          <option value="super_admin">Super admin</option>
        </select>
      </div>

      {errorMessage && (
        <div style={{
          padding: 'var(--space-md)',
          backgroundColor: 'var(--color-danger-bg)',
          color: 'var(--color-danger-hover)',
          borderRadius: 'var(--radius)',
          borderLeft: '3px solid var(--color-danger)',
          marginBottom: 'var(--space-md)',
        }}>
          {errorMessage}
        </div>
      )}

      {isLoading ? (
        <LoadingSpinner label="Chargement des utilisateurs…" />
      ) : (
        <>
          <DataTable
            columns={COLUMNS}
            rows={data.users}
            onRowClick={(u) => navigate(`/users/${u.id}`)}
            emptyMessage="Aucun utilisateur ne correspond aux filtres"
          />
          <div style={{ marginTop: 'var(--space-md)' }}>
            <div className="data-table-wrapper" style={{ borderRadius: 'var(--radius-lg)' }}>
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
