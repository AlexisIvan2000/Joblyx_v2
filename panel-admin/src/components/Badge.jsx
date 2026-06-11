import '../styles/components/badge.css';

export default function Badge({ children, variant = 'default', withDot = false }) {
  return (
    <span className={`badge badge-${variant}`}>
      {withDot && <span className="badge-dot" />}
      {children}
    </span>
  );
}
