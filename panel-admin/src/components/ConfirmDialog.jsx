import { useEffect, useState } from 'react';
import Modal from './Modal';
import '../styles/components/button.css';


export default function ConfirmDialog({
  isOpen,
  title,
  message,
  confirmLabel = 'Confirmer',
  confirmVariant = 'primary',
  withReasonInput = false,
  reasonPlaceholder = 'Raison (optionnel)…',
  onConfirm,
  onCancel,
}) {
  const [reason, setReason] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // Reset du state quand on ferme
  useEffect(() => {
    if (!isOpen) {
      setReason('');
      setIsLoading(false);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  async function handleConfirm() {
    setIsLoading(true);
    try {
      await onConfirm(reason.trim() || null);
    } finally {
      setIsLoading(false);
    }
  }

  const confirmClass = confirmVariant === 'danger' ? 'btn-danger-solid' : 'btn-primary';

  return (
    <Modal onClose={onCancel} labelledBy="confirm-dialog-title">
      <h3 className="dialog-title" id="confirm-dialog-title">{title}</h3>
      <p className="dialog-message">{message}</p>

      {withReasonInput && (
        <input
          type="text"
          className="dialog-input"
          placeholder={reasonPlaceholder}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          disabled={isLoading}
          autoFocus
        />
      )}

      <div className="dialog-actions">
        <button type="button" className="btn btn-secondary" onClick={onCancel} disabled={isLoading}>
          Annuler
        </button>
        <button type="button" className={`btn ${confirmClass}`} onClick={handleConfirm} disabled={isLoading}>
          {isLoading ? 'Patientez…' : confirmLabel}
        </button>
      </div>
    </Modal>
  );
}
