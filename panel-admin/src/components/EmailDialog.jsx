import { useEffect, useState } from 'react';
import { Mail } from 'lucide-react';
import Modal from './Modal';
import '../styles/components/button.css';
import '../styles/components/email-dialog.css';


const SUBJECT_MAX = 200;
const BODY_MAX = 10000;

export default function EmailDialog({ isOpen, userEmail, userName, onConfirm, onCancel }) {
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // Reset du state quand on ferme
  useEffect(() => {
    if (!isOpen) {
      setSubject('');
      setBody('');
      setIsLoading(false);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const canSend = subject.trim().length > 0 && body.trim().length > 0 && !isLoading;

  async function handleConfirm() {
    if (!canSend) return;
    setIsLoading(true);
    try {
      await onConfirm({ subject: subject.trim(), body: body.trim() });
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Modal onClose={onCancel} labelledBy="email-dialog-title" className="email-dialog">
      <div className="email-dialog-header">
        <h3 className="dialog-title" id="email-dialog-title">
            <Mail size={18} strokeWidth={2.25} style={{ verticalAlign: '-3px', marginRight: 6 }} />
            Envoyer un email
          </h3>
          <p className="email-dialog-recipient">
            À : <strong>{userName}</strong> <span className="muted">·</span> <span className="muted">{userEmail}</span>
          </p>
        </div>

        <label className="email-dialog-label">
          <span>Objet</span>
          <input
            type="text"
            className="email-dialog-input"
            placeholder="Ex : Suite à votre signalement"
            value={subject}
            onChange={(e) => setSubject(e.target.value.slice(0, SUBJECT_MAX))}
            disabled={isLoading}
            autoFocus
          />
          <span className="email-dialog-count">{subject.length} / {SUBJECT_MAX}</span>
        </label>

        <label className="email-dialog-label">
          <span>Message</span>
          <textarea
            className="email-dialog-textarea"
            placeholder={`Bonjour ${(userName || '').split(' ')[0] || ''},\n\nVotre message ici…\n\nCordialement,\nL'équipe Joblyx`}
            value={body}
            onChange={(e) => setBody(e.target.value.slice(0, BODY_MAX))}
            disabled={isLoading}
            rows={9}
          />
          <span className="email-dialog-count">{body.length} / {BODY_MAX}</span>
        </label>

        <p className="email-dialog-hint">
          Le message sera envoyé en HTML avec le logo Joblyx. Les sauts de ligne sont conservés.
        </p>

        <div className="dialog-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancel} disabled={isLoading}>
            Annuler
          </button>
          <button type="button" className="btn btn-primary" onClick={handleConfirm} disabled={!canSend}>
            {isLoading ? 'Envoi…' : 'Envoyer'}
          </button>
        </div>
    </Modal>
  );
}
