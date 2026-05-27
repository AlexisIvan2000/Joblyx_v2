import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)
from core.exceptions import (
    LinkedInOnlyAccount,
    IncorrectCurrentPassword,
    IncorrectPassword,
    SamePasswordAsBefore,
    PasswordAlreadySet,
    InvalidOrExpiredResetCode,
    InvalidResetCode,
    ResetCodeExpired,
    TooManyVerificationAttempts,
    InvalidVerificationCode,
    VerificationCodeExpired,
    NoPendingEmailChange,
    NoEmailChangeCode,
    EmailMismatch,
    EmailAlreadyInUse,
    UserNotFound,
    NoFieldsToUpdate,
    CannotDeleteSuperAdmin,
)
from core.security import Security
from core.password import validate_password
from models.schemas import UpdateProfile
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.emailing.otp_service import OtpService

MAX_VERIFICATION_ATTEMPTS = 5


class UserService:
    def __init__(self, auth_repo: AuthRepository, otp_service: OtpService, refresh_token_repo: RefreshTokenRepository | None = None):
        self.repo = auth_repo
        self.otp_svc = otp_service
        self.rt_repo = refresh_token_repo

    async def update_profile(self, user_id: str, data: UpdateProfile):
        data_dict = data.model_dump(exclude_none=True)
        if not data_dict:
            raise NoFieldsToUpdate()
        await self.repo.update_user(user_id, data_dict)
        return {"message": "Profile updated successfully"}

    async def change_password(self, user_id: str, current_password: str, new_password: str):
        validate_password(new_password)
        db_user = await self.repo.get_user_by_id(user_id)
        if not db_user.password_hash:
            raise LinkedInOnlyAccount()
        if not Security.verify_password(db_user.password_hash, current_password):
            raise IncorrectCurrentPassword()
        if Security.verify_password(db_user.password_hash, new_password):
            raise SamePasswordAsBefore()
        new_hash = Security.hash_password(new_password)
        await self.repo.update_user(user_id, {"password_hash": new_hash})
        logger.info("Password changed: user_id=%s", user_id)
        # Révoquer tous les refresh tokens (déconnexion de tous les appareils)
        if self.rt_repo:
            await self.rt_repo.revoke_all_for_user(user_id)
        return {"message": "Password changed successfully"}

    async def set_password(self, user_id: str, new_password: str):
       
        validate_password(new_password)
        db_user = await self.repo.get_user_by_id(user_id)
        if db_user.password_hash:
            raise PasswordAlreadySet()
        new_hash = Security.hash_password(new_password)
        await self.repo.update_user(user_id, {"password_hash": new_hash})
        logger.info("Password set for LinkedIn account: user_id=%s", user_id)
        return {"message": "Password set successfully"}

    async def forgot_password(self, email: str):
        db_user = await self.repo.get_user_by_email(email)
        if db_user:
            # Compte créé via LinkedIn sans mot de passe
            if not db_user.password_hash:
                raise LinkedInOnlyAccount()
            await self.otp_svc.send_reset_otp(email)
        return {"message": "If this email is registered, a reset code has been sent"}

    async def reset_password(self, email: str, code: str, new_password: str):
        validate_password(new_password)
        db_user = await self.repo.get_user_by_email(email)
        if not db_user or not db_user.reset_code_hash:
            raise InvalidOrExpiredResetCode()

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise TooManyVerificationAttempts()

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.reset_code_hash:
            raise InvalidResetCode()

        expires_at = db_user.reset_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise ResetCodeExpired()

        if Security.verify_password(db_user.password_hash, new_password):
            raise SamePasswordAsBefore()
        new_hash = Security.hash_password(new_password)
        await self.repo.update_password(str(db_user.id), new_hash)
        # Révoquer tous les refresh tokens (déconnexion de tous les appareils)
        if self.rt_repo:
            await self.rt_repo.revoke_all_for_user(str(db_user.id))
        return {"message": "Password reset successfully"}

    async def request_email_change(self, user_id: str, new_email: str, password: str):
        db_user = await self.repo.get_user_by_id(user_id)
        if not db_user.password_hash:
            raise LinkedInOnlyAccount()
        if not Security.verify_password(db_user.password_hash, password):
            raise IncorrectPassword()
        if await self.repo.get_user_by_email(new_email):
            raise EmailAlreadyInUse()

        await self.repo.update_user(user_id, {"pending_email": new_email})
        await self.otp_svc.send_email_change_otp(new_email, user_id)
        return {"message": "Verification code sent to new address"}

    async def confirm_email_change(self, user_id: str, code: str):
        db_user = await self.repo.get_user_by_id(user_id)
        if not db_user:
            raise UserNotFound()

        pending_email = db_user.pending_email
        if not pending_email:
            raise NoPendingEmailChange()

        if not db_user.email_change_code_hash:
            raise NoEmailChangeCode()

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise TooManyVerificationAttempts()

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.email_change_code_hash:
            raise InvalidVerificationCode()

        expires_at = db_user.email_change_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise VerificationCodeExpired()

        await self.repo.update_user(str(db_user.id), {
            "email": pending_email,
            "pending_email": None,
            "email_change_code_hash": None,
            "email_change_code_expires_at": None,
            "verification_attempts": 0,
        })
        return {"message": "Email changed successfully"}

    async def delete_account(
        self,
        user_id: str,
        email_confirmation: str,
        r2_service=None,
        application_repo=None,
        coach_repo=None,
    ):
        
        db_user = await self.repo.get_user_by_id(user_id)
        if not db_user:
            raise UserNotFound()

        # Le super_admin est unique et ne peut jamais être supprimé, même par lui-même
        if db_user.role == "super_admin":
            raise CannotDeleteSuperAdmin()

        if db_user.email != email_confirmation:
            raise EmailMismatch()

        # Collecte les file_keys AVANT le CASCADE (sinon les rows sont déjà supprimées)
        cv_keys: list[str] = []
        avatar_key: str | None = None

        if r2_service is not None:
            if application_repo is not None:
                cv_keys.extend(await application_repo.get_cv_keys_for_user(user_id))
            if coach_repo is not None:
                cv_keys.extend(await coach_repo.get_cv_keys_for_user(user_id))

            # Avatar : file_key R2 uniquement, pas une URL externe (ui-avatars, LinkedIn)
            if db_user.avatar_url and not db_user.avatar_url.startswith("http"):
                avatar_key = db_user.avatar_url

        # Supprime le user — les FK CASCADE suppriment toutes les données liées
        await self.repo.delete_user(user_id)
        logger.info("Account deleted: user_id=%s email=%s", user_id, db_user.email)

        # Nettoyage R2 best-effort  un échec laisse les fichiers orphelins mais ne casse pas la suppression
        if r2_service is not None:
            for key in cv_keys:
                try:
                    await r2_service.delete_cv(key)
                except Exception:
                    logger.warning("Failed to delete CV from R2: key=%s", key)
            if avatar_key:
                try:
                    await r2_service.delete_avatar(avatar_key)
                except Exception:
                    logger.warning("Failed to delete avatar from R2: key=%s", avatar_key)

        return {"message": "Account deleted successfully"}
