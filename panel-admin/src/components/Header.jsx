import { useLocation } from 'react-router-dom';
import { Menu } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';
import ThemeToggle from './ThemeToggle';
import '../styles/components/header.css';

const TITLES = {
  '/dashboard': 'Dashboard',
  '/users': 'Utilisateurs',
  '/errors': 'Erreurs',
  '/audit': 'Audit log',
};

function getTitle(pathname) {
  if (pathname.startsWith('/users/')) return 'Détail utilisateur';
  if (pathname.startsWith('/errors/')) return 'Détail erreur';
  return TITLES[pathname] || 'Joblyx Admin';
}

function getInitials(firstName, lastName) {
  const a = (firstName || '').charAt(0).toUpperCase();
  const b = (lastName || '').charAt(0).toUpperCase();
  return `${a}${b}` || '?';
}

function roleLabel(role) {
  if (role === 'super_admin') return 'Super admin';
  if (role === 'admin') return 'Admin';
  return role || '';
}

export default function Header({ onToggleMobileSidebar }) {
  const location = useLocation();
  const { user } = useAuth();

  return (
    <header className="app-header">
      <div className="header-left">
        <button
          type="button"
          className="header-burger"
          onClick={onToggleMobileSidebar}
          aria-label="Ouvrir le menu"
        >
          <Menu size={20} strokeWidth={2.25} />
        </button>
        <h1 className="header-title">{getTitle(location.pathname)}</h1>
      </div>

      <div className="header-actions">
        <ThemeToggle />
        {user && (
          <div className="header-user">
            <div className="header-user-avatar">{getInitials(user.first_name, user.last_name)}</div>
            <div className="header-user-info">
              <span className="header-user-name">{user.first_name} {user.last_name}</span>
              <span className="header-user-role">{roleLabel(user.role)}</span>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
