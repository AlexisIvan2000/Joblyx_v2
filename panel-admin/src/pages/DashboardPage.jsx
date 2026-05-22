import { useCallback } from 'react';
import { useState } from 'react';
import {
  Users, ShieldCheck, Activity, Map, Briefcase, MessageSquare, Mic, DollarSign,
} from 'lucide-react';
import StatCard from '../components/StatCard';
import LiveIndicator from '../components/LiveIndicator';
import RegistrationsChart from '../components/RegistrationsChart';
import { DashboardSkeleton } from '../components/Skeleton';
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

  if (stats.isLoading) return <DashboardSkeleton />;
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
            value={s.total_users}
            formatter={formatNumber}
            icon={Users}
            variant="accent"
          />
          <StatCard
            title="Vérifiés"
            value={s.verified_users}
            formatter={formatNumber}
            subtitle={s.total_users > 0 ? `${Math.round((s.verified_users / s.total_users) * 100)}% du total` : null}
            icon={ShieldCheck}
            variant="success"
          />
          <StatCard
            title="Actifs (7j)"
            value={s.active_users_week}
            formatter={formatNumber}
            subtitle="Connectés cette semaine"
            icon={Activity}
          />
        </div>
      </section>

      {/* Section 2 — Contenu généré */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Contenu</h2>
        <div className="dashboard-grid">
          <StatCard
            title="Roadmaps totales"
            value={s.total_roadmaps}
            formatter={formatNumber}
            subtitle={`${s.ai_roadmaps} IA · ${s.manual_roadmaps} manuelles`}
            icon={Map}
          />
          <StatCard
            title="Candidatures"
            value={s.total_applications}
            formatter={formatNumber}
            icon={Briefcase}
          />
          <StatCard
            title="Coach (mois)"
            value={s.coach_sessions_month}
            formatter={formatNumber}
            subtitle="Analyses CV ce mois"
            icon={MessageSquare}
          />
          <StatCard
            title="Interview (mois)"
            value={s.interview_sessions_month}
            formatter={formatNumber}
            subtitle="Simulations ce mois"
            icon={Mic}
          />
        </div>
      </section>

      {/* Section 3 — Coût IA */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Coût IA estimé</h2>
        <div className="dashboard-grid">
          <StatCard
            title="OpenAI cumulé"
            value={s.openai_usage_estimate_usd}
            formatter={formatUSD}
            subtitle="Estimation à la louche, pas un tracking précis"
            icon={DollarSign}
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
