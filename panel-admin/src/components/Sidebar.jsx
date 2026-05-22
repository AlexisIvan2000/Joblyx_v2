import { NavLink, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Users, ScrollText, AlertTriangle, LogOut, X } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';
import '../styles/components/sidebar.css';

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/users', label: 'Utilisateurs', icon: Users },
  { to: '/errors', label: 'Erreurs', icon: AlertTriangle },
  { to: '/audit', label: 'Audit log', icon: ScrollText },
];

export default function Sidebar({ isMobileOpen = false, onCloseMobile }) {
  const navigate = useNavigate();
  const { logout } = useAuth();

  async function handleLogout() {
    await logout();
    navigate('/login', { replace: true });
  }

  return (
    <>
      {isMobileOpen && (
        <div className="app-sidebar-backdrop" onClick={onCloseMobile} />
      )}

      <aside className={`app-sidebar ${isMobileOpen ? 'is-open' : ''}`}>
        <div className="sidebar-brand">
          <img src="/assets/joblyx_logo.png" alt="Joblyx" className="sidebar-brand-logo" />
          <div className="sidebar-brand-text">
            <span className="sidebar-brand-name">Joblyx</span>
            <span className="sidebar-brand-tag">Admin</span>
          </div>
          <button
            type="button"
            className="sidebar-close-mobile"
            onClick={onCloseMobile}
            aria-label="Fermer le menu"
          >
            <X size={20} strokeWidth={2.25} />
          </button>
        </div>

        <nav className="sidebar-nav">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={onCloseMobile}
                className={({ isActive }) => `sidebar-link ${isActive ? 'active' : ''}`}
              >
                <span className="sidebar-link-icon">
                  <Icon size={20} strokeWidth={2} />
                </span>
                <span>{item.label}</span>
              </NavLink>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <button type="button" className="sidebar-logout" onClick={handleLogout}>
            <span className="sidebar-link-icon">
              <LogOut size={20} strokeWidth={2} />
            </span>
            <span>Déconnexion</span>
          </button>
        </div>
      </aside>
    </>
  );
}
