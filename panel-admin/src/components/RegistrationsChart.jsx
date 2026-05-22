import { useMemo } from 'react';
import {
  Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts';
import { formatDate } from '../utils/format';

// Tooltip custom au style premium (carte arrondie, ombre, accent primary)
function ChartTooltip({ active, payload }) {
  if (!active || !payload || !payload.length) return null;
  const point = payload[0].payload;
  return (
    <div className="chart-tooltip">
      <div className="chart-tooltip-date">{formatDate(point.date)}</div>
      <div className="chart-tooltip-value">
        <span className="chart-tooltip-dot" />
        <span className="chart-tooltip-count">{point.count}</span>
        <span className="chart-tooltip-label">inscription{point.count > 1 ? 's' : ''}</span>
      </div>
    </div>
  );
}

export default function RegistrationsChart({ data }) {
  // Stats résumées (total + moyenne sur la période)
  const summary = useMemo(() => {
    if (!data || data.length === 0) return { total: 0, average: 0, peak: 0 };
    const total = data.reduce((acc, p) => acc + p.count, 0);
    const peak = Math.max(...data.map((p) => p.count));
    return {
      total,
      average: (total / data.length).toFixed(1),
      peak,
    };
  }, [data]);

  if (!data || data.length === 0) {
    return <div className="dashboard-empty">Aucune inscription sur la période</div>;
  }

  return (
    <div>
      {/* KPI résumé au-dessus de la courbe */}
      <div className="chart-summary">
        <div className="chart-summary-item">
          <span className="chart-summary-label">Total</span>
          <span className="chart-summary-value">{summary.total}</span>
        </div>
        <div className="chart-summary-divider" />
        <div className="chart-summary-item">
          <span className="chart-summary-label">Moyenne/jour</span>
          <span className="chart-summary-value">{summary.average}</span>
        </div>
        <div className="chart-summary-divider" />
        <div className="chart-summary-item">
          <span className="chart-summary-label">Pic</span>
          <span className="chart-summary-value">{summary.peak}</span>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={240}>
        <AreaChart data={data} margin={{ top: 16, right: 12, left: -12, bottom: 0 }}>
          <defs>
            <linearGradient id="registrations-gradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-primary)" stopOpacity={0.32} />
              <stop offset="100%" stopColor="var(--color-primary)" stopOpacity={0} />
            </linearGradient>
            {/* Glow filter sous la ligne, effet "halo lumineux" */}
            <filter id="registrations-glow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="3" result="blur" />
              <feFlood floodColor="var(--color-primary)" floodOpacity="0.5" />
              <feComposite in2="blur" operator="in" />
              <feMerge>
                <feMergeNode />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>

          <CartesianGrid
            stroke="var(--color-border)"
            strokeDasharray="0"
            vertical={false}
            opacity={0.5}
          />

          <XAxis
            dataKey="label"
            tick={{ fontSize: 11, fill: 'var(--color-text-muted)', fontWeight: 500 }}
            axisLine={false}
            tickLine={false}
            dy={8}
          />

          <YAxis
            allowDecimals={false}
            tick={{ fontSize: 11, fill: 'var(--color-text-muted)', fontWeight: 500 }}
            axisLine={false}
            tickLine={false}
            width={32}
          />

          <Tooltip
            content={<ChartTooltip />}
            cursor={{ stroke: 'var(--color-primary)', strokeWidth: 1, strokeDasharray: '3 3' }}
          />

          <Area
            type="monotone"
            dataKey="count"
            stroke="var(--color-primary)"
            strokeWidth={2.5}
            fill="url(#registrations-gradient)"
            filter="url(#registrations-glow)"
            isAnimationActive={true}
            animationDuration={1200}
            animationEasing="ease-out"
            activeDot={{
              r: 5,
              fill: 'var(--color-primary)',
              stroke: 'var(--color-surface)',
              strokeWidth: 3,
            }}
            dot={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
