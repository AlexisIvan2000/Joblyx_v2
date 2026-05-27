import { useCountUp } from '../hooks/useCountUp';
import '../styles/components/card.css';

export default function StatCard({
  title, value, subtitle, variant = 'default',
  icon: Icon, trend, formatter,
}) {
  const isNumeric = typeof value === 'number' && !Number.isNaN(value);
  const animated = useCountUp(isNumeric ? value : 0, { duration: 900 });
  const display = isNumeric
    ? (formatter ? formatter(animated) : Math.round(animated))
    : value;

  const variantClass = variant === 'default' ? '' : `stat-card-${variant}`;
  return (
    <div className={`card stat-card ${variantClass}`}>
      <div className="stat-card-header">
        <div className="card-title">{title}</div>
        {Icon && (
          <div className="stat-card-icon">
            <Icon size={16} strokeWidth={2.25} />
          </div>
        )}
      </div>
      <div className="stat-card-value">{display}</div>
      {trend && (
        <div className={`stat-card-trend ${trend.value >= 0 ? 'is-up' : 'is-down'}`}>
          <span className="stat-card-trend-arrow">{trend.value >= 0 ? '↗' : '↘'}</span>
          <span>{trend.value > 0 ? '+' : ''}{trend.value}%</span>
          {trend.label && <span className="muted">· {trend.label}</span>}
        </div>
      )}
      {subtitle && <div className="stat-card-subtitle">{subtitle}</div>}
    </div>
  );
}
