import { useEffect, useState } from 'react';
import { ShieldAlert } from 'lucide-react';
import '../styles/components/button.css';

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
  {
    value: 'super_admin',
    label: 'Super admin',
    description: 'Accès complet, peut modifier les autres admins et changer les rôles',
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

  const isDangerous = selectedRole === 'super_admin' && currentRole !== 'super_admin';
  const isDemotion = currentRole === 'super_admin' && selectedRole !== 'super_admin';

  return (
    <div className="dialog-backdrop" onClick={onCancel}>
      <div className="dialog" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 520 }}>
        <h3 className="dialog-title">Modifier le rôle</h3>
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

        {(isDangerous || isDemotion) && (
          <div className="role-warning">
            <ShieldAlert size={16} strokeWidth={2.25} />
            <span>
              {isDangerous
                ? "Attention : ce rôle a un accès complet et peut modifier d'autres admins."
                : "Attention : cet admin perdra ses privilèges actuels."}
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
            className={`btn ${isDangerous ? 'btn-danger-solid' : 'btn-primary'}`}
            onClick={handleConfirm}
            disabled={isLoading || selectedRole === currentRole}
          >
            {isLoading ? 'Mise à jour…' : 'Appliquer'}
          </button>
        </div>
      </div>
    </div>
  );
}
