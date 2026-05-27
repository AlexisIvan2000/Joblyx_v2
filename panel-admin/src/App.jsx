import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import { ProtectedRoute } from './auth/ProtectedRoute';
import { ErrorBoundary } from './components/ErrorBoundary';
import LoadingSpinner from './components/LoadingSpinner';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import './App.css';



const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const UsersPage = lazy(() => import('./pages/UsersPage'));
const UserDetailPage = lazy(() => import('./pages/UserDetailPage'));
const AuditLogPage = lazy(() => import('./pages/AuditLogPage'));
const ErrorsPage = lazy(() => import('./pages/ErrorsPage'));
const ErrorDetailPage = lazy(() => import('./pages/ErrorDetailPage'));
const NotFoundPage = lazy(() => import('./pages/NotFoundPage'));

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ErrorBoundary>
          <Suspense fallback={<LoadingSpinner label="Chargement…" />}>
            <Routes>
              <Route path="/login" element={<LoginPage />} />

              {/* Toutes les routes protégées partagent le Layout (sidebar + header) */}
              <Route
                element={
                  <ProtectedRoute>
                    <Layout />
                  </ProtectedRoute>
                }
              >
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/users" element={<UsersPage />} />
                <Route path="/users/:id" element={<UserDetailPage />} />
                <Route path="/errors" element={<ErrorsPage />} />
                <Route path="/errors/:id" element={<ErrorDetailPage />} />
                <Route path="/audit" element={<AuditLogPage />} />
              </Route>

              <Route path="/" element={<Navigate to="/dashboard" replace />} />
              <Route path="*" element={<NotFoundPage />} />
            </Routes>
          </Suspense>
        </ErrorBoundary>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
