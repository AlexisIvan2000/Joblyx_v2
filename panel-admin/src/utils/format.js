// Formatters de présentation — chiffres, devise, dates

const NUMBER_FORMAT = new Intl.NumberFormat('fr-FR');
const CURRENCY_FORMAT = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
});

export function formatNumber(n) {
  if (n === null || n === undefined) return '—';
  return NUMBER_FORMAT.format(n);
}

export function formatUSD(n) {
  if (n === null || n === undefined) return '—';
  return CURRENCY_FORMAT.format(n);
}

export function formatDate(iso) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString('fr-FR', {
      day: '2-digit', month: 'short', year: 'numeric',
    });
  } catch {
    return iso;
  }
}

export function formatDateTime(iso) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('fr-FR', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

export function formatDayLabel(isoDate) {
  // Pour les labels du graphique : "21 mai"
  if (!isoDate) return '';
  try {
    return new Date(isoDate).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
  } catch {
    return isoDate;
  }
}
