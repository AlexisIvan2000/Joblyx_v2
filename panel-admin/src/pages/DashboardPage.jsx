import { useCallback } from 'react';
import { useState } from 'react';
import StatCard from '../components/StatCard';
import LoadingSpinner from '../components/LoadingSpinner';
import LiveIndicator from '../components/LiveIndicator';
import RegistrationsChart from '../components/RegistrationsChart';
import { getStats, getRegistrations } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import { formatNumber, formatUSD, formatDayLabel } from '../utils/format';
import { usePoll } from '../hooks/usePoll';
import '../styles/pages/dashboard.css';
import '../styles/components/live-indicator.css';

// Intervalles de polling : stats globales rafraîchies toutes les 15s, le graph toutes les 30s
const STATS_INTERVAL = 15000;
const REGISTRATIONS_INTERVAL = 30000;

export default function DashboardPage() {
  const [period, setPeriod] = useState('week');

  const fetchStats = useCallback(() => getStats(), []);
  const fetchRegistrations = useCallback(async () => {
    const data = await getRegistrations(period);
    return data.map((point) => ({ ...point, label: formatDayLabel(point.date) }));
  }, [period]);

  const stats = usePoll(fetchStats, [], { interval: STATS_INTERVAL });
  const registrations = usePoll(fetchRegistrations, [period], { interval: REGISTRATIONS_INTERVAL });

  if (stats.isLoading) return <LoadingSpinner label="Chargement des statistiques…" />;
  if (stats.error) return <div className="dashboard-error">{getErrorMessage(stats.error)}</div>;
  if (!stats.data) return null;

  const s = stats.data;

  return (
    <div>
      {/* Live indicator + dernière update */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 'var(--space-md)' }}>
        <LiveIndicator
          lastUpdate={stats.lastUpdate}
          isRefreshing={stats.isRefreshing || registrations.isRefreshing}
          onRefresh={() => { stats.refetch(); registrations.refetch(); }}
        />
      </div>

      {/* Section 1 — Utilisateurs */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Utilisateurs</h2>
        <div className="dashboard-grid">
          <StatCard
            title="Total"
            value={formatNumber(s.total_users)}
            variant="accent"
          />
          <StatCard
            title="Vérifiés"
            value={formatNumber(s.verified_users)}
            subtitle={s.total_users > 0 ? `${Math.round((s.verified_users / s.total_users) * 100)}% du total` : null}
            variant="success"
          />
          <StatCard
            title="Actifs (7j)"
            value={formatNumber(s.active_users_week)}
            subtitle="Connectés cette semaine"
          />
        </div>
      </section>

      {/* Section 2 — Contenu généré */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Contenu</h2>
        <div className="dashboard-grid">
          <StatCard
            title="Roadmaps totales"
            value={formatNumber(s.total_roadmaps)}
            subtitle={`${s.ai_roadmaps} IA · ${s.manual_roadmaps} manuelles`}
          />
          <StatCard
            title="Candidatures"
            value={formatNumber(s.total_applications)}
          />
          <StatCard
            title="Coach (mois)"
            value={formatNumber(s.coach_sessions_month)}
            subtitle="Analyses CV ce mois"
          />
          <StatCard
            title="Interview (mois)"
            value={formatNumber(s.interview_sessions_month)}
            subtitle="Simulations ce mois"
          />
        </div>
      </section>

      {/* Section 3 — Coût IA */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Coût IA estimé</h2>
        <div className="dashboard-grid">
          <StatCard
            title="OpenAI cumulé"
            value={formatUSD(s.openai_usage_estimate_usd)}
            subtitle="Estimation à la louche, pas un tracking précis"
            variant="warning"
          />
        </div>
      </section>

      {/* Section 4 — Graph inscriptions */}
      <section className="dashboard-section">
        <div className="dashboard-chart-card">
          <div className="dashboard-chart-header">
            <h3 className="dashboard-chart-title">Inscriptions</h3>
            <select
              className="dashboard-period-select"
              value={period}
              onChange={(e) => setPeriod(e.target.value)}
            >
              <option value="week">7 derniers jours</option>
              <option value="month">30 derniers jours</option>
            </select>
          </div>

          <RegistrationsChart data={registrations.data || []} />
        </div>
      </section>
    </div>
  );
}
