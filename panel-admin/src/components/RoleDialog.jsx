import { useEffect, useState } from 'react';
import { ShieldAlert } from 'lucide-react';
import Modal from './Modal';
import '../styles/components/button.css';

// Seuls user et admin sont assignables, super_admin reste unique (founder)
const ROLES = [
  {
    value: 'user',
    label: 'User',
    description: 'Utilisateur standard sans accès admin',
  },
  {
    value: 'admin',
    label: 'Admin',
    description: 'Accès au panel admin, peut gérer les utilisateurs normaux',
  },
];

export default function RoleDialog({ isOpen, currentRole, userName, onConfirm, onCancel }) {
  const [selectedRole, setSelectedRole] = useState(currentRole);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setSelectedRole(currentRole);
      setIsLoading(false);
    }
  }, [isOpen, currentRole]);

  if (!isOpen) return null;

  async function handleConfirm() {
    if (selectedRole === currentRole) return;
    setIsLoading(true);
    try {
      await onConfirm(selectedRole);
    } finally {
      setIsLoading(false);
    }
  }

  const isDemotion = currentRole === 'admin' && selectedRole === 'user';
  const isPromotion = currentRole === 'user' && selectedRole === 'admin';

  return (
    <Modal onClose={onCancel} labelledBy="role-dialog-title" style={{ maxWidth: 520 }}>
      <h3 className="dialog-title" id="role-dialog-title">Modifier le rôle</h3>
      <p className="dialog-message">
          Choisis le nouveau rôle pour <strong>{userName}</strong>. Le changement prend effet à la prochaine connexion de l'utilisateur (ou à son prochain refresh de token).
        </p>

        <div className="role-options">
          {ROLES.map((role) => (
            <label
              key={role.value}
              className={`role-option ${selectedRole === role.value ? 'is-selected' : ''}`}
            >
              <input
                type="radio"
                name="role"
                value={role.value}
                checked={selectedRole === role.value}
                onChange={() => setSelectedRole(role.value)}
                disabled={isLoading}
              />
              <div className="role-option-content">
                <div className="role-option-label">
                  {role.label}
                  {role.value === currentRole && (
                    <span className="role-option-badge">Actuel</span>
                  )}
                </div>
                <div className="role-option-description">{role.description}</div>
              </div>
            </label>
          ))}
        </div>

        {(isDemotion || isPromotion) && (
          <div className="role-warning">
            <ShieldAlert size={16} strokeWidth={2.25} />
            <span>
              {isPromotion
                ? "Cet user aura accès au panel admin et pourra gérer les autres users."
                : "Cet admin perdra ses privilèges et redeviendra un utilisateur standard."}
            </span>
          </div>
        )}

        <div className="dialog-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={onCancel}
            disabled={isLoading}
          >
            Annuler
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={handleConfirm}
            disabled={isLoading || selectedRole === currentRole}
          >
            {isLoading ? 'Mise à jour…' : 'Appliquer'}
          </button>
        </div>
    </Modal>
  );
}
