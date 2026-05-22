// Indicateur visuel "données live" — pulse vert + timestamp dernière update

import { useEffect, useState } from 'react';

function formatRelative(timestamp) {
  if (!timestamp) return null;
  const seconds = Math.floor((Date.now() - timestamp) / 1000);
  if (seconds < 5) return 'à l\'instant';
  if (seconds < 60) return `il y a ${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `il y a ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  return `il y a ${hours}h`;
}

export default function LiveIndicator({ lastUpdate, isRefreshing, onRefresh }) {
  // Force re-render toutes les 5s pour mettre à jour le texte "il y a X secondes"
  const [, tick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => tick((t) => t + 1), 5000);
    return () => clearInterval(id);
  }, []);

  return (
    <button
      type="button"
      className="live-indicator"
      onClick={onRefresh}
      title="Rafraîchir maintenant"
    >
      <span className={`live-indicator-dot ${isRefreshing ? 'is-refreshing' : ''}`} />
      <span className="live-indicator-text">
        {isRefreshing ? 'Synchronisation…' : `Live · ${formatRelative(lastUpdate) || 'jamais'}`}
      </span>
    </button>
  );
}
