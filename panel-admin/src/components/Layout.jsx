import { useState, useEffect } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';
import '../styles/components/layout.css';

export default function Layout() {
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
  const location = useLocation();

  // Ferme la sidebar mobile à chaque changement de route
  useEffect(() => {
    setIsMobileSidebarOpen(false);
  }, [location.pathname]);

  return (
    <div className="app-layout">
      <Sidebar
        isMobileOpen={isMobileSidebarOpen}
        onCloseMobile={() => setIsMobileSidebarOpen(false)}
      />
      <Header onToggleMobileSidebar={() => setIsMobileSidebarOpen(true)} />
      <main className="app-main">
        {/* La key force le remount du conteneur à chaque route, déclenche l'animation page-enter */}
        <div className="app-main-inner page-enter" key={location.pathname}>
          <Outlet />
        </div>
      </main>
    </div>
  );
}
