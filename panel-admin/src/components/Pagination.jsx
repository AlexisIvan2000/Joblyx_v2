import { useEffect } from 'react';

function getPages(currentPage, totalPages) {
  if (totalPages <= 7) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }
  // Logique compacte avec ellipses
  if (currentPage <= 4) {
    return [1, 2, 3, 4, 5, '…', totalPages];
  }
  if (currentPage >= totalPages - 3) {
    return [1, '…', totalPages - 4, totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
  }
  return [1, '…', currentPage - 1, currentPage, currentPage + 1, '…', totalPages];
}

export default function Pagination({ page, pageSize, total, onChange }) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const pages = getPages(page, totalPages);
  const start = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  // Si la page courante dépasse le total (ex: dernier item supprimé), on recale
  useEffect(() => {
    if (page > totalPages) onChange(totalPages);
  }, [page, totalPages, onChange]);

  if (totalPages <= 1) {
    return (
      <div className="pagination">
        <div className="pagination-info">
          {total} résultat{total > 1 ? 's' : ''}
        </div>
      </div>
    );
  }

  return (
    <div className="pagination">
      <div className="pagination-info">
        {start}–{end} sur {total}
      </div>
      <div className="pagination-buttons">
        <button
          type="button"
          className="pagination-button"
          onClick={() => onChange(page - 1)}
          disabled={page === 1}
        >
          ‹
        </button>
        {pages.map((p, i) =>
          p === '…' ? (
            <span key={`gap-${i}`} className="pagination-button" style={{ border: 'none', background: 'transparent', cursor: 'default' }}>…</span>
          ) : (
            <button
              key={p}
              type="button"
              className={`pagination-button ${p === page ? 'active' : ''}`}
              onClick={() => onChange(p)}
            >
              {p}
            </button>
          ),
        )}
        <button
          type="button"
          className="pagination-button"
          onClick={() => onChange(page + 1)}
          disabled={page === totalPages}
        >
          ›
        </button>
      </div>
    </div>
  );
}
