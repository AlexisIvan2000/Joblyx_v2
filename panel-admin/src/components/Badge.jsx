import '../styles/components/badge.css';

// Petite pill colorée pour role/status/etc.
// variant : 'default' | 'success' | 'danger' | 'warning' | 'primary'

export default function Badge({ children, variant = 'default', withDot = false }) {
  return (
    <span className={`badge badge-${variant}`}>
      {withDot && <span className="badge-dot" />}
      {children}
    </span>
  );
}
