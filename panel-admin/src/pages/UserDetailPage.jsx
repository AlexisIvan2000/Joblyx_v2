import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ShieldCheck, NotebookPen, Check, Mail, Lock } from 'lucide-react';
import { UserDetailSkeleton } from '../components/Skeleton';
import Badge from '../components/Badge';
import ConfirmDialog from '../components/ConfirmDialog';
import RoleDialog from '../components/RoleDialog';
import EmailDialog from '../components/EmailDialog';
import { useAuth } from '../auth/AuthContext';
import {
  getUserDetail, setUserStatus, resetUserLimits, deleteUser, updateUserRole, updateUserNotes, sendEmailToUser,
} from '../api/admin';
import { getErrorMessage } from '../api/errors';
import { formatDateTime } from '../utils/format';
import '../styles/pages/user-detail.css';
import '../styles/components/button.css';

const REGENERATION_LIMIT = 5;
const COACH_WEEKLY_LIMIT = 3;
const INTERVIEW_DAILY_LIMIT = 2;

function roleLabel(role) {
  if (role === 'super_admin') return 'Super admin';
  if (role === 'admin') return 'Admin';
  return 'User';
}

function UsageBar({ used, limit }) {
  const pct = Math.min(100, Math.round((used / limit) * 100));
  const variant = pct >= 100 ? 'danger' : pct >= 75 ? 'warning' : '';
  return (
    <div className="user-detail-usage-bar">
      <div className="text-xs muted">{used} / {limit}</div>
      <div className="user-detail-usage-bar-track">
        <div className={`user-detail-usage-bar-fill ${variant}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function Row({ label, value }) {
  return (
    <div className="user-detail-row">
      <span className="user-detail-row-label">{label}</span>
      <span className="user-detail-row-value">{value ?? '—'}</span>
    </div>
  );
}

export default function UserDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user: currentUser } = useAuth();

  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Modales
  const [showStatusDialog, setShowStatusDialog] = useState(false);
  const [showResetDialog, setShowResetDialog] = useState(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showRoleDialog, setShowRoleDialog] = useState(false);
  const [showEmailDialog, setShowEmailDialog] = useState(false);

  // Toast d'action
  const [actionError, setActionError] = useState(null);
  const [actionSuccess, setActionSuccess] = useState(null);

  // Notes admin (édition inline)
  const [notesDraft, setNotesDraft] = useState('');
  const [isSavingNotes, setIsSavingNotes] = useState(false);
  const [notesSavedAt, setNotesSavedAt] = useState(null);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getUserDetail(id);
      setUser(data);
      setNotesDraft(data.admin_notes || '');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => { load(); }, [id]);  // eslint-disable-line react-hooks/exhaustive-deps

  async function handleToggleStatus(reason) {
    setActionError(null);
    try {
      await setUserStatus(id, { isActive: !user.is_active, reason });
      setShowStatusDialog(false);
      await load();
    } catch (err) {
      setActionError(getErrorMessage(err));
    }
  }

  async function handleResetLimits() {
    setActionError(null);
    try {
      await resetUserLimits(id);
      setShowResetDialog(false);
      await load();
    } catch (err) {
      setActionError(getErrorMessage(err));
    }
  }

  async function handleDelete() {
    setActionError(null);
    try {
      await deleteUser(id);
      setShowDeleteDialog(false);
      navigate('/users', { replace: true });
    } catch (err) {
      setActionError(getErrorMessage(err));
    }
  }

  async function handleUpdateRole(newRole) {
    setActionError(null);
    try {
      await updateUserRole(id, newRole);
      setShowRoleDialog(false);
      await load();
    } catch (err) {
      setActionError(getErrorMessage(err));
    }
  }

  async function handleSendEmail({ subject, body }) {
    setActionError(null);
    setActionSuccess(null);
    try {
      await sendEmailToUser(id, { subject, body });
      setShowEmailDialog(false);
      setActionSuccess(`Email envoyé à ${user.email}`);
      setTimeout(() => setActionSuccess(null), 4000);
    } catch (err) {
      setActionError(getErrorMessage(err));
    }
  }

  async function handleSaveNotes() {
    setActionError(null);
    setIsSavingNotes(true);
    try {
      const result = await updateUserNotes(id, notesDraft);
      setUser((prev) => prev ? { ...prev, admin_notes: result.admin_notes } : prev);
      setNotesSavedAt(Date.now());
      // Le badge "Enregistré" s'efface après 2.5s
      setTimeout(() => setNotesSavedAt(null), 2500);
    } catch (err) {
      setActionError(getErrorMessage(err));
    } finally {
      setIsSavingNotes(false);
    }
  }

  if (isLoading) return <UserDetailSkeleton />;
  if (error) {
    return (
      <div>
        <button type="button" className="user-detail-back" onClick={() => navigate(-1)}>
          ← Retour
        </button>
        <div style={{
          padding: 'var(--space-md)',
          backgroundColor: 'var(--color-danger-bg)',
          color: 'var(--color-danger-hover)',
          borderRadius: 'var(--radius)',
          borderLeft: '3px solid var(--color-danger)',
        }}>
          {error}
        </div>
      </div>
    );
  }
  if (!user) return null;

  const usage = user.usage || {};
  const career = user.career;
  const roadmap = user.active_roadmap;
  const applications = user.applications || [];
  const coachHistory = user.coach_history || [];
  const interviewHistory = user.interview_history || [];

  // Verrouillage : founder = lecture seule pour tous, super_admin = lecture seule pour les admins non super
  const isSuper = currentUser?.role === 'super_admin';
  const isLocked = user.is_founder || (user.role === 'super_admin' && !isSuper);
  const lockReason = user.is_founder
    ? 'Compte fondateur (verrouillé)'
    : 'Réservé super_admin';

  return (
    <div>
      <button type="button" className="user-detail-back" onClick={() => navigate(-1)}>
        ← Retour
      </button>

      <div className="user-detail-header">
        <div className="user-detail-identity">
          <h2>{user.first_name} {user.last_name}</h2>
          <div className="user-detail-identity-meta">
            <span>{user.email}</span>
            <span>·</span>
            <Badge variant={user.role === 'super_admin' ? 'primary' : user.role === 'admin' ? 'warning' : 'default'}>
              {roleLabel(user.role)}
            </Badge>
            <Badge variant={user.is_active ? 'success' : 'danger'} withDot>
              {user.is_active ? 'Actif' : 'Désactivé'}
            </Badge>
            {!user.is_verified && <Badge variant="warning">Non vérifié</Badge>}
          </div>
        </div>

        <div className="user-detail-actions">
          {isLocked ? (
            <Badge variant="default">
              <Lock size={13} strokeWidth={2.25} style={{ verticalAlign: '-2px', marginRight: 4 }} />
              {lockReason}
            </Badge>
          ) : (
            <>
              {isSuper && currentUser?.id !== user.id && user.role !== 'super_admin' && (
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowRoleDialog(true)}
                >
                  <ShieldCheck size={16} strokeWidth={2.25} />
                  Modifier le rôle
                </button>
              )}
              {isSuper && (
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowEmailDialog(true)}
                >
                  <Mail size={16} strokeWidth={2.25} />
                  Envoyer un email
                </button>
              )}
              <button
                type="button"
                className={`btn ${user.is_active ? 'btn-danger' : 'btn-success'}`}
                onClick={() => setShowStatusDialog(true)}
              >
                {user.is_active ? 'Désactiver' : 'Réactiver'}
              </button>
              <button type="button" className="btn btn-secondary" onClick={() => setShowResetDialog(true)}>
                Reset limites
              </button>
              <button type="button" className="btn btn-danger-solid" onClick={() => setShowDeleteDialog(true)}>
                Supprimer
              </button>
            </>
          )}
        </div>
      </div>

      {actionError && (
        <div style={{
          padding: 'var(--space-md)',
          backgroundColor: 'var(--color-danger-bg)',
          color: 'var(--color-danger-hover)',
          borderRadius: 'var(--radius)',
          borderLeft: '3px solid var(--color-danger)',
          marginBottom: 'var(--space-md)',
        }}>
          {actionError}
        </div>
      )}

      {actionSuccess && (
        <div style={{
          padding: 'var(--space-md)',
          backgroundColor: 'var(--color-success-bg)',
          color: 'var(--color-success-hover, var(--color-success))',
          borderRadius: 'var(--radius)',
          borderLeft: '3px solid var(--color-success)',
          marginBottom: 'var(--space-md)',
        }}>
          {actionSuccess}
        </div>
      )}

      <div className="user-detail-sections">
        {/* Notes admin (texte libre, jamais exposé au user) */}
        <section className="user-detail-section">
          <div className="admin-notes-header">
            <h3>
              <NotebookPen size={16} strokeWidth={2.25} style={{ verticalAlign: '-2px', marginRight: 6 }} />
              Notes admin
            </h3>
            {notesSavedAt && (
              <span className="admin-notes-saved">
                <Check size={13} strokeWidth={2.5} /> Enregistré
              </span>
            )}
          </div>
          <textarea
            className="admin-notes-textarea"
            value={notesDraft}
            onChange={(e) => setNotesDraft(e.target.value)}
            placeholder={isLocked
              ? 'Notes en lecture seule sur un compte verrouillé'
              : 'Ajouter une note interne sur ce user (visible uniquement par les admins)…'}
            rows={4}
            maxLength={5000}
            disabled={isLocked}
          />
          <div className="admin-notes-footer">
            <span className="muted text-xs">
              {notesDraft.length} / 5000 · jamais affiché au user
            </span>
            <button
              type="button"
              className="btn btn-primary"
              onClick={handleSaveNotes}
              disabled={isLocked || isSavingNotes || (notesDraft || '') === (user.admin_notes || '')}
            >
              {isSavingNotes ? 'Enregistrement…' : 'Enregistrer'}
            </button>
          </div>
        </section>

        {/* Profil */}
        <section className="user-detail-section">
          <h3>Profil</h3>
          <div className="user-detail-list">
            <Row label="Email vérifié" value={user.is_verified ? 'Oui' : 'Non'} />
            <Row label="Authentification" value={user.has_linkedin ? 'LinkedIn' : 'Email + Password'} />
            <Row label="Inscrit le" value={formatDateTime(user.created_at)} />
            <Row label="Dernière activité" value={formatDateTime(user.last_active)} />
            {!user.is_active && user.deactivated_at && (
              <Row label="Désactivé le" value={formatDateTime(user.deactivated_at)} />
            )}
            {!user.is_active && user.deactivation_reason && (
              <Row label="Raison" value={user.deactivation_reason} />
            )}
          </div>
        </section>

        {/* Career */}
        <section className="user-detail-section">
          <h3>Carrière</h3>
          {career ? (
            <div className="user-detail-list">
              <Row label="Niveau" value={career.level} />
              <Row label="Années d'expérience" value={career.years_experience} />
              <Row label="Métiers visés" value={(career.target_jobs || []).join(', ') || '—'} />
              <Row label="Ville" value={`${career.city}, ${career.province}`} />
              <Row label="Langue" value={career.language} />
              <Row label="Génération roadmap" value={career.generation_status} />
            </div>
          ) : (
            <div className="user-detail-empty">Profil carrière non rempli</div>
          )}
        </section>

        {/* Compétences */}
        <section className="user-detail-section">
          <h3>Compétences ({(user.skills || []).length})</h3>
          {(user.skills || []).length > 0 ? (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-xs)' }}>
              {user.skills.map((s, i) => (
                <Badge key={i} variant="default">
                  {s.skill_name} · {s.proficiency}
                </Badge>
              ))}
            </div>
          ) : (
            <div className="user-detail-empty">Aucune compétence enregistrée</div>
          )}
        </section>

        {/* Roadmap active */}
        <section className="user-detail-section">
          <h3>Roadmap active</h3>
          {roadmap ? (
            <div className="user-detail-list">
              <Row label="Statut" value={roadmap.status} />
              <Row label="Phases" value={`${roadmap.completed_phase_count} / ${roadmap.phase_count}`} />
              <Row label="Créée le" value={formatDateTime(roadmap.created_at)} />
            </div>
          ) : (
            <div className="user-detail-empty">Aucune roadmap active</div>
          )}
        </section>

        {/* Candidatures */}
        <section className="user-detail-section">
          <h3>Candidatures ({applications.length})</h3>
          {applications.length > 0 ? (
            <div className="user-detail-list">
              {applications.slice(0, 5).map((a) => (
                <Row
                  key={a.id}
                  label={`${a.job_title} · ${a.company_name}`}
                  value={<Badge variant="default">{a.status}</Badge>}
                />
              ))}
              {applications.length > 5 && (
                <div className="muted text-xs">+ {applications.length - 5} autres</div>
              )}
            </div>
          ) : (
            <div className="user-detail-empty">Aucune candidature</div>
          )}
        </section>

        {/* Coach */}
        <section className="user-detail-section">
          <h3>Coach IA ({coachHistory.length})</h3>
          {coachHistory.length > 0 ? (
            <div className="user-detail-list">
              {coachHistory.slice(0, 5).map((c) => (
                <Row
                  key={c.id}
                  label={c.job_title || '—'}
                  value={c.compatibility_score != null ? `${c.compatibility_score}%` : '—'}
                />
              ))}
              {coachHistory.length > 5 && (
                <div className="muted text-xs">+ {coachHistory.length - 5} autres</div>
              )}
            </div>
          ) : (
            <div className="user-detail-empty">Aucune session coach</div>
          )}
        </section>

        {/* Interview */}
        <section className="user-detail-section">
          <h3>Interview ({interviewHistory.length})</h3>
          {interviewHistory.length > 0 ? (
            <div className="user-detail-list">
              {interviewHistory.slice(0, 5).map((i) => (
                <Row
                  key={i.id}
                  label={i.job_title}
                  value={i.overall_score != null ? `${i.overall_score}/100` : i.status}
                />
              ))}
              {interviewHistory.length > 5 && (
                <div className="muted text-xs">+ {interviewHistory.length - 5} autres</div>
              )}
            </div>
          ) : (
            <div className="user-detail-empty">Aucune session interview</div>
          )}
        </section>

        {/* Limites d'usage */}
        <section className="user-detail-section">
          <h3>Limites d'usage</h3>
          <div className="user-detail-list">
            <div className="user-detail-row" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
              <span className="user-detail-row-label">Régénérations roadmap (mois)</span>
              <UsageBar used={usage.regeneration_count || 0} limit={REGENERATION_LIMIT} />
            </div>
            <div className="user-detail-row" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
              <span className="user-detail-row-label">Analyses coach (semaine)</span>
              <UsageBar used={usage.coach_usage_count || 0} limit={COACH_WEEKLY_LIMIT} />
            </div>
            <div className="user-detail-row" style={{ flexDirection: 'column', alignItems: 'stretch' }}>
              <span className="user-detail-row-label">Sessions interview (jour)</span>
              <UsageBar used={usage.interview_usage_count || 0} limit={INTERVIEW_DAILY_LIMIT} />
            </div>
          </div>
        </section>
      </div>

      {/* Modales */}
      <ConfirmDialog
        isOpen={showStatusDialog}
        title={user.is_active ? 'Désactiver ce compte ?' : 'Réactiver ce compte ?'}
        message={
          user.is_active
            ? "L'utilisateur ne pourra plus se connecter et ses tokens de session seront révoqués."
            : "L'utilisateur pourra à nouveau se connecter à son compte."
        }
        confirmLabel={user.is_active ? 'Désactiver' : 'Réactiver'}
        confirmVariant={user.is_active ? 'danger' : 'primary'}
        withReasonInput={user.is_active}
        reasonPlaceholder="Raison (optionnel, visible dans l'audit log)"
        onConfirm={handleToggleStatus}
        onCancel={() => setShowStatusDialog(false)}
      />

      <ConfirmDialog
        isOpen={showResetDialog}
        title="Réinitialiser les limites d'usage ?"
        message="Les compteurs de régénération roadmap, analyses coach et sessions interview seront remis à zéro pour cet utilisateur."
        confirmLabel="Réinitialiser"
        confirmVariant="primary"
        onConfirm={handleResetLimits}
        onCancel={() => setShowResetDialog(false)}
      />

      <ConfirmDialog
        isOpen={showDeleteDialog}
        title="Supprimer définitivement ce compte ?"
        message={`Toutes les données de ${user.email} seront supprimées (roadmaps, candidatures, sessions, CV stockés). Cette action est irréversible.`}
        confirmLabel="Supprimer définitivement"
        confirmVariant="danger"
        onConfirm={handleDelete}
        onCancel={() => setShowDeleteDialog(false)}
      />

      <RoleDialog
        isOpen={showRoleDialog}
        currentRole={user.role}
        userName={`${user.first_name} ${user.last_name}`}
        onConfirm={handleUpdateRole}
        onCancel={() => setShowRoleDialog(false)}
      />

      <EmailDialog
        isOpen={showEmailDialog}
        userEmail={user.email}
        userName={`${user.first_name} ${user.last_name}`}
        onConfirm={handleSendEmail}
        onCancel={() => setShowEmailDialog(false)}
      />
    </div>
  );
}
