import '../styles/components/card.css';

// Carte de stat réutilisable  title + valeur + sous-titre optionnel
// variant : 'default' | 'accent' | 'success' | 'warning' | 'danger'

export default function StatCard({ title, value, subtitle, variant = 'default' }) {
  const variantClass = variant === 'default' ? '' : `stat-card-${variant}`;
  return (
    <div className={`card ${variantClass}`}>
      <div className="card-title">{title}</div>
      <div className="stat-card-value">{value}</div>
      {subtitle && <div className="stat-card-subtitle">{subtitle}</div>}
    </div>
  );
}
