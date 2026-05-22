"""Exceptions métier centralisées — chaque cas d'erreur de l'API a sa propre classe.

Les services lèvent ces exceptions sans argument (sauf cas paramétrés).
Le handler global dans app.py les traduit en réponses HTTP JSON normalisées.
"""


class DomainError(Exception):
    # Erreur métier de base traduite en réponse HTTP par le handler global
    status_code: int = 500
    error_code: str = "internal_error"
    default_message: str = "An internal error occurred"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        msg = message or self.default_message
        super().__init__(msg)
        self.message = msg
        self.details = details or {}


# Bases génériques  utilisées quand aucune classe spécifique ne correspond

class NotFoundError(DomainError):
    status_code = 404
    error_code = "not_found"
    default_message = "Resource not found"


class ConflictError(DomainError):
    status_code = 409
    error_code = "conflict"
    default_message = "Conflict with current state"


class ValidationError(DomainError):
    status_code = 400
    error_code = "validation_error"
    default_message = "Invalid data"


class UnauthorizedError(DomainError):
    status_code = 401
    error_code = "unauthorized"
    default_message = "Authentication required"


class ForbiddenError(DomainError):
    status_code = 403
    error_code = "forbidden"
    default_message = "Access denied"


class RateLimitError(DomainError):
    status_code = 429
    error_code = "rate_limit_exceeded"
    default_message = "Rate limit exceeded"


class ExternalServiceError(DomainError):
    status_code = 502
    error_code = "external_service_error"
    default_message = "External service error"


# Authentification login / register / refresh

class InvalidCredentials(UnauthorizedError):
    default_message = "Invalid email or password"


class EmailAlreadyRegistered(ConflictError):
    default_message = "Email already registered"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "email"})


class EmailNotVerified(ForbiddenError):
    default_message = "Please verify your email before logging in"


class UserBanned(ForbiddenError):
    default_message = "Your account has been banned"


# Admin — protection des endpoints /v1/admin/*

class AdminAccessRequired(ForbiddenError):
    default_message = "Admin privileges required"


class SuperAdminAccessRequired(ForbiddenError):
    default_message = "Super admin privileges required for this action"


class CannotBanSelf(ValidationError):
    default_message = "You cannot ban your own account"


class CannotDeleteSelf(ValidationError):
    default_message = "You cannot delete your own account via the admin endpoint"


class CannotModifyAdmin(ForbiddenError):
    default_message = "Only a super admin can modify another admin account"


class CannotModifyFounder(ForbiddenError):
    default_message = "The founder account is locked and cannot be modified via the panel"


class CannotPromoteToSuperAdmin(ValidationError):
    default_message = "Promoting to super_admin is not allowed via the panel"


class LinkedInOnlyAccount(ValidationError):
    default_message = "This account uses LinkedIn sign-in"


class InvalidRefreshToken(UnauthorizedError):
    default_message = "Invalid or expired refresh token"


class LinkedInAuthFailed(UnauthorizedError):
    default_message = "Failed to authenticate with LinkedIn"


class LinkedInProfileFetchFailed(UnauthorizedError):
    default_message = "Failed to fetch LinkedIn profile"


class LinkedInMissingEmail(ValidationError):
    default_message = "LinkedIn account has no email address"


# Mots de passe

class WeakPassword(ValidationError):
    default_message = "Password must be at least 8 characters with a special character"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "password"})


class PasswordTooShort(WeakPassword):
    default_message = "Password must be at least 8 characters"


class PasswordMissingSpecial(WeakPassword):
    default_message = "Password must contain at least one special character"


class IncorrectCurrentPassword(UnauthorizedError):
    default_message = "Current password is incorrect"


class IncorrectPassword(UnauthorizedError):
    default_message = "Invalid password"


class SamePasswordAsBefore(ValidationError):
    default_message = "New password must be different from current password"


class PasswordAlreadySet(ConflictError):
    default_message = "Account already has a password"


# Codes de vérification / reset (OTP)

class InvalidVerificationCode(ValidationError):
    default_message = "Invalid verification code"


class VerificationCodeExpired(ValidationError):
    default_message = "Verification code expired. Please request a new one."


class InvalidVerificationRequest(ValidationError):
    default_message = "Invalid verification request"


class InvalidResetCode(ValidationError):
    default_message = "Invalid reset code"


class InvalidOrExpiredResetCode(ValidationError):
    default_message = "Invalid or expired reset code"


class ResetCodeExpired(ValidationError):
    default_message = "Reset code has expired"


class TooManyVerificationAttempts(RateLimitError):
    default_message = "Too many attempts, request a new code"


class TooManyCodeRequests(RateLimitError):
    default_message = "Too many code requests, please try again later"


# Changement d'email

class NoPendingEmailChange(ValidationError):
    default_message = "No pending email change"


class NoEmailChangeCode(ValidationError):
    default_message = "No email change code found"


class EmailMismatch(ValidationError):
    default_message = "Email does not match your account"


class EmailAlreadyInUse(ConflictError):
    default_message = "Email already in use"


# Ressources

class UserNotFound(NotFoundError):
    default_message = "User not found"


class ProfileNotFound(NotFoundError):
    default_message = "Profile not found"


class OnboardingAlreadyCompleted(ConflictError):
    default_message = "Onboarding already completed"


class ApplicationNotFound(NotFoundError):
    default_message = "Application not found"


class NoCvAttached(NotFoundError):
    default_message = "No CV attached to this application"


class SessionNotFound(NotFoundError):
    default_message = "Session not found"


class SessionAlreadyCompleted(ValidationError):
    default_message = "Session already completed"


class NoFieldsToUpdate(ValidationError):
    default_message = "No fields to update"


# Roadmap

class RoadmapNotFound(NotFoundError):
    default_message = "Roadmap not found"


class NoActiveRoadmap(NotFoundError):
    default_message = "No active roadmap"


class NoArchivedRoadmap(NotFoundError):
    default_message = "Roadmap not found or not archived"


class PhaseNotFound(NotFoundError):
    default_message = "Phase not found"


class ActionNotFound(NotFoundError):
    default_message = "Action not found"


class SkillIndexNotFound(NotFoundError):
    default_message = "Skill not found"


class CareerProfileRequired(NotFoundError):
    default_message = "Career profile not found. Complete onboarding first."


class RoadmapRegenerationLimitReached(RateLimitError):
    default_message = "Monthly regeneration limit reached (5 per month)"


class InvalidPhaseIdsForReorder(ValidationError):
    default_message = "phase_ids must match all phases of the active roadmap"


# Coach IA

class CoachWeeklyLimitReached(RateLimitError):
    default_message = "Weekly coach analysis limit reached (3 per week)"


class CvTextExtractionFailed(ValidationError):
    default_message = "Failed to extract text from CV"


# Simulateur d'entretien

class InterviewDailyLimitReached(RateLimitError):
    default_message = "Daily interview session limit reached"


# Validation titre de poste

class JobTitleRequired(ValidationError):
    default_message = "Job title is required"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "job_title"})


class JobTitleTooLong(ValidationError):
    default_message = "Job title is too long"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "job_title"})


class JobTitleInvalidCharacters(ValidationError):
    default_message = "Job title contains invalid characters"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "job_title"})


class JobTitleNotIT(ValidationError):
    default_message = "Job title must be related to IT/tech"

    def __init__(self, message: str | None = None, *, details: dict | None = None):
        super().__init__(message, details=details or {"field": "job_title"})
