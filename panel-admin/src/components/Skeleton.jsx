import '../styles/components/skeleton.css';

export default function Skeleton({ width = '100%', height = '1em', rounded = '', className = '', style = {} }) {
  return (
    <span
      className={`skeleton skeleton-${rounded || 'default'} ${className}`}
      style={{ width, height, ...style }}
      aria-hidden="true"
    />
  );
}

// Skeletons composés pour les vues principales

export function DashboardSkeleton() {
  return (
    <div className="skeleton-dashboard">
      {/* Indicator placeholder */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 'var(--space-md)' }}>
        <Skeleton width={140} height={32} rounded="pill" />
      </div>

      {[1, 2, 3].map((section) => (
        <div key={section} style={{ marginBottom: 'var(--space-2xl)' }}>
          <Skeleton width={100} height={12} rounded="sm" style={{ marginBottom: '0.875rem' }} />
          <div className="dashboard-grid">
            {[1, 2, 3].map((card) => (
              <div key={card} className="skeleton-card">
                <div className="skeleton-card-header">
                  <Skeleton width={80} height={12} rounded="sm" />
                  <Skeleton width={32} height={32} rounded="sm" />
                </div>
                <Skeleton width={120} height={40} rounded="sm" style={{ marginTop: 4 }} />
                <Skeleton width="60%" height={11} rounded="sm" style={{ marginTop: 12 }} />
              </div>
            ))}
          </div>
        </div>
      ))}

      {/* Chart skeleton */}
      <div className="skeleton-card" style={{ padding: '1.5rem 1.625rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-md)' }}>
          <Skeleton width={120} height={18} rounded="sm" />
          <Skeleton width={140} height={36} rounded="pill" />
        </div>
        <Skeleton width="100%" height={240} rounded="default" />
      </div>
    </div>
  );
}

export function TableSkeleton({ rows = 8, cols = 5 }) {
  return (
    <div className="skeleton-table">
      <div className="skeleton-table-head">
        {Array.from({ length: cols }).map((_, i) => (
          <Skeleton key={i} height={14} rounded="sm" width={`${60 + Math.random() * 30}%`} />
        ))}
      </div>
      {Array.from({ length: rows }).map((_, r) => (
        <div className="skeleton-table-row" key={r}>
          {Array.from({ length: cols }).map((_, c) => (
            <Skeleton key={c} height={14} rounded="sm" width={`${40 + Math.random() * 50}%`} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function UserDetailSkeleton() {
  return (
    <div>
      <Skeleton width={80} height={20} rounded="sm" style={{ marginBottom: 'var(--space-md)' }} />
      <div className="skeleton-card" style={{ marginBottom: 'var(--space-lg)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 16 }}>
          <div style={{ flex: 1, minWidth: 240 }}>
            <Skeleton width={220} height={28} rounded="sm" />
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <Skeleton width={120} height={14} rounded="sm" />
              <Skeleton width={60} height={20} rounded="pill" />
              <Skeleton width={70} height={20} rounded="pill" />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <Skeleton width={120} height={36} rounded="pill" />
            <Skeleton width={100} height={36} rounded="pill" />
          </div>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--space-md)' }}>
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="skeleton-card">
            <Skeleton width={100} height={16} rounded="sm" style={{ marginBottom: 16 }} />
            {[1, 2, 3].map((j) => (
              <div key={j} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                <Skeleton width="40%" height={12} rounded="sm" />
                <Skeleton width="30%" height={12} rounded="sm" />
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
