import { useEffect, useRef } from 'react';

// Coquille de modale : backdrop, fermeture sur Escape et clic extérieur,
// attributs ARIA (role/aria-modal/aria-labelledby) et focus initial pour le clavier.
export default function Modal({ onClose, labelledBy, className = '', style, children }) {
  const dialogRef = useRef(null);

  useEffect(() => {
    function onKey(e) {
      if (e.key === 'Escape') onClose();
    }
    document.addEventListener('keydown', onKey);
    // Focus la modale à l'ouverture (lecteurs d'écran + navigation clavier)
    dialogRef.current?.focus();
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="dialog-backdrop" onClick={onClose}>
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        tabIndex={-1}
        className={`dialog ${className}`.trim()}
        style={style}
        onClick={(e) => e.stopPropagation()}
      >
        {children}
      </div>
    </div>
  );
}
