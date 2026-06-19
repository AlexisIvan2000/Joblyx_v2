import logging

logger = logging.getLogger(__name__)
from models.schemas import UserCreate, UserLogin
from core.security import Security
from core.password import validate_password
from core.exceptions import (
    DisposableEmailNotAllowed,
    EmailAlreadyRegistered,
    InvalidCredentials,
    LinkedInOnlyAccount,
    EmailNotVerified,
    InvalidVerificationRequest,
    InvalidVerificationCode,
    VerificationCodeExpired,
    TooManyVerificationAttempts,
    NoPendingEmailChange,
    InvalidRefreshToken,
    UserBanned,
)
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.auth.disposable_email import is_disposable_email
from services.emailing.otp_service import OtpService
from datetime import datetime, timedelta, timezone

MAX_VERIFICATION_ATTEMPTS = 5


class EmailPasswordAuth:
    def __init__(self, auth_repo: AuthRepository, refresh_token_repo: RefreshTokenRepository, otp_service: OtpService):
        self.repo = auth_repo
        self.rt_repo = refresh_token_repo
        self.otp_svc = otp_service

    async def register_user(self, user: UserCreate):
        validate_password(user.password)

        if is_disposable_email(user.email):
            logger.warning("Registration blocked: email=%s reason=disposable", user.email)
            raise DisposableEmailNotAllowed()

        if await self.repo.get_user_by_email(user.email):
            raise EmailAlreadyRegistered()

        hashed_password = Security.hash_password(user.password)

        user_data = {
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "password_hash": hashed_password,
        }

        new_user = await self.repo.create_user(user_data)
        logger.info("User registered: user_id=%s email=%s", new_user.id, user.email)

        await self.otp_svc.send_verification_otp(user.email, str(new_user.id))

        return {"message": "Account created. Please check your email for the verification code."}

    async def login_user(self, user: UserLogin):
        db_user = await self.repo.get_user_by_email(user.email)
        if not db_user:
            logger.warning("Login failed: email=%s reason=not_found", user.email)
            raise InvalidCredentials()
        if not db_user.password_hash:
            logger.warning("Login failed: user_id=%s reason=linkedin_only", db_user.id)
            raise LinkedInOnlyAccount()
        if not Security.verify_password(db_user.password_hash, user.password):
            logger.warning("Login failed: user_id=%s reason=wrong_password", db_user.id)
            raise InvalidCredentials()
        if not db_user.is_verified:
            raise EmailNotVerified()
        if not db_user.is_active:
            logger.warning("Login blocked: user_id=%s reason=deactivated", db_user.id)
            raise UserBanned()
        user_id = str(db_user.id)
        logger.info("Login success: user_id=%s email=%s role=%s", user_id, user.email, db_user.role)
        access_token = Security.create_access_token(user_id, role=db_user.role)
        refresh_token = Security.create_refresh_token(user_id)

        token_hash = Security.hash_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, token_hash, refresh_expires)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "role": db_user.role,
        }

    async def verify_email(self, email: str, code: str):
        db_user = await self.repo.get_user_by_email(email)
        if not db_user or db_user.is_verified:
            raise InvalidVerificationRequest()

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise TooManyVerificationAttempts()

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.verification_code_hash:
            raise InvalidVerificationCode()

        expires_at = db_user.verification_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise VerificationCodeExpired()

        user_id = str(db_user.id)
        await self.repo.update_verification_status(user_id)

        access_token = Security.create_access_token(user_id, role=db_user.role)
        refresh_token = Security.create_refresh_token(user_id)

        token_hash = Security.hash_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, token_hash, refresh_expires)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "role": db_user.role,
        }

    async def resend_verification_email(self, email: str):
        db_user = await self.repo.get_user_by_email(email)
        if db_user and not db_user.is_verified:
            await self.otp_svc.send_verification_otp(email, str(db_user.id), db_user=db_user)
        return {"message": "If this email is registered and unverified, a new verification code has been sent"}

    async def resend_email_change_verification(self, user_id: str):
        db_user = await self.repo.get_user_by_id(user_id)
        pending_email = db_user.pending_email
        if not pending_email:
            raise NoPendingEmailChange()

        await self.otp_svc.send_email_change_otp(pending_email, user_id, db_user=db_user)
        return {"message": "Verification code resent to new address"}

    async def refresh_access_token(self, refresh_token: str):
        payload = Security.decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise InvalidRefreshToken()

        token_hash = Security.hash_token(refresh_token)
        db_token = await self.rt_repo.get_by_token_hash(token_hash)
        if not db_token:
            raise InvalidRefreshToken()

        await self.rt_repo.revoke(token_hash)

        user_id = payload.get("sub")
    
        db_user = await self.repo.get_user_by_id(user_id)
        role = db_user.role if db_user else "user"
        new_access_token = Security.create_access_token(user_id, role=role)
        new_refresh_token = Security.create_refresh_token(user_id)

        new_token_hash = Security.hash_token(new_refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, new_token_hash, refresh_expires)

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
            "role": role,
        }

    async def logout_user(self, refresh_token: str):
        token_hash = Security.hash_token(refresh_token)
        await self.rt_repo.revoke(token_hash)
        return {"message": "User logged out successfully"}
