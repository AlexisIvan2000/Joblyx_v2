import { useEffect, useState } from 'react';
import StatCard from '../components/StatCard';
import LoadingSpinner from '../components/LoadingSpinner';
import RegistrationsChart from '../components/RegistrationsChart';
import { getStats, getRegistrations } from '../api/admin';
import { getErrorMessage } from '../api/errors';
import { formatNumber, formatUSD, formatDayLabel } from '../utils/format';
import '../styles/pages/dashboard.css';

export default function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [registrations, setRegistrations] = useState([]);
  const [period, setPeriod] = useState('week');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Chargement initial des stats globales
  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    setError(null);
    getStats()
      .then((data) => { if (!cancelled) setStats(data); })
      .catch((err) => { if (!cancelled) setError(getErrorMessage(err)); })
      .finally(() => { if (!cancelled) setIsLoading(false); });
    return () => { cancelled = true; };
  }, []);

  // Rechargement du graph quand la période change
  useEffect(() => {
    let cancelled = false;
    getRegistrations(period)
      .then((data) => {
        if (cancelled) return;
        const formatted = data.map((point) => ({
          ...point,
          label: formatDayLabel(point.date),
        }));
        setRegistrations(formatted);
      })
      .catch(() => { /* l'erreur globale est gérée par le useEffect précédent */ });
    return () => { cancelled = true; };
  }, [period]);

  if (isLoading) return <LoadingSpinner label="Chargement des statistiques…" />;
  if (error) return <div className="dashboard-error">{error}</div>;
  if (!stats) return null;

  return (
    <div>
      {/* Section 1 — Utilisateurs */}
      <section className="dashboard-section">
        <h2 className="dashboard-section-title">Utilisateurs</h2>
        <div className="dashboard-grid">
          <StatCard
            title="Total"
            value={formatNumber(stats.total_users)}
            variant="accent"
          />
          <StatCard
            title="Vérifiés"
            value={formatNumber(stats.verified_users)}
            subtitle={stats.total_users > 0 ? `${Math.round((stats.verified_users / stats.total_users) * 100)}% du total` : null}
            variant="success"
          />
          <StatCard
            title="Actifs (7j)"
            value={formatNumber(stats.active_users_week)}
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
            value={formatNumber(stats.total_roadmaps)}
            subtitle={`${stats.ai_roadmaps} IA · ${stats.manual_roadmaps} manuelles`}
          />
          <StatCard
            title="Candidatures"
            value={formatNumber(stats.total_applications)}
          />
          <StatCard
            title="Coach (mois)"
            value={formatNumber(stats.coach_sessions_month)}
            subtitle="Analyses CV ce mois"
          />
          <StatCard
            title="Interview (mois)"
            value={formatNumber(stats.interview_sessions_month)}
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
            value={formatUSD(stats.openai_usage_estimate_usd)}
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

          <RegistrationsChart data={registrations} />
        </div>
      </section>
    </div>
  );
}
