from fastapi import HTTPException, status
from models.schemas import UserCreate, UserLogin
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.emailing.email_sender import EmailSender
from datetime import datetime, timedelta, timezone

MAX_VERIFICATION_ATTEMPTS = 5
MAX_RESEND_PER_HOUR = 5
OTP_EXPIRY_MINUTES = 15


class EmailPasswordAuth:
    def __init__(self, auth_repo: AuthRepository, refresh_token_repo: RefreshTokenRepository):
        self.repo = auth_repo
        self.rt_repo = refresh_token_repo

    async def register_user(self, user: UserCreate):
        if await self.repo.get_user_by_email(user.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        hashed_password = Security.hash_password(user.password)

        new_user = await self.repo.create_user({
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "password_hash": hashed_password,
        })
        user_id = str(new_user.id)

        otp_code = Security.generate_otp_code()
        code_hash = Security.hash_token(otp_code)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
        await self.repo.update_user(user_id, {
            "verification_code_hash": code_hash,
            "verification_code_expires_at": expires_at,
            "verification_attempts": 0,
            "last_code_sent_at": datetime.now(timezone.utc),
            "code_resend_count": 1,
        })
        EmailSender().send_verification_email(user.email, code=otp_code)

        return {"message": "Account created. Please check your email for the verification code."}

    async def login_user(self, user: UserLogin):
        db_user = await self.repo.get_user_by_email(user.email)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        if not Security.verify_password(db_user.password_hash, user.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        if not db_user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email before logging in"
            )
        user_id = str(db_user.id)
        access_token = Security.create_access_token(user_id)
        refresh_token = Security.create_refresh_token(user_id)

        token_hash = Security.hash_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, token_hash, refresh_expires)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    async def verify_email(self, email: str, code: str):
        db_user = await self.repo.get_user_by_email(email)
        if not db_user or db_user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification request"
            )

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many attempts, request a new code"
            )

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.verification_code_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification code"
            )

        expires_at = db_user.verification_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verification code expired. Please request a new one."
            )

        user_id = str(db_user.id)
        await self.repo.update_verification_status(user_id)

        access_token = Security.create_access_token(user_id)
        refresh_token = Security.create_refresh_token(user_id)

        token_hash = Security.hash_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, token_hash, refresh_expires)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    async def resend_verification_email(self, email: str):
        db_user = await self.repo.get_user_by_email(email)
        if db_user and not db_user.is_verified:
            self._check_resend_rate_limit(db_user)

            otp_code = Security.generate_otp_code()
            code_hash = Security.hash_token(otp_code)
            expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
            now = datetime.now(timezone.utc)

            new_resend_count = self._compute_resend_count(db_user, now)

            await self.repo.update_user(str(db_user.id), {
                "verification_code_hash": code_hash,
                "verification_code_expires_at": expires_at,
                "verification_attempts": 0,
                "last_code_sent_at": now,
                "code_resend_count": new_resend_count,
            })
            EmailSender().send_verification_email(email, code=otp_code)
        return {"message": "If this email is registered and unverified, a new verification code has been sent"}

    async def resend_email_change_verification(self, user_id: str):
        db_user = await self.repo.get_user_by_id(user_id)
        pending_email = db_user.pending_email
        if not pending_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No pending email change"
            )

        self._check_resend_rate_limit(db_user)

        otp_code = Security.generate_otp_code()
        code_hash = Security.hash_token(otp_code)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
        now = datetime.now(timezone.utc)

        new_resend_count = self._compute_resend_count(db_user, now)

        await self.repo.update_user(user_id, {
            "email_change_code_hash": code_hash,
            "email_change_code_expires_at": expires_at,
            "verification_attempts": 0,
            "last_code_sent_at": now,
            "code_resend_count": new_resend_count,
        })
        EmailSender().send_email_change_email(pending_email, code=otp_code)
        return {"message": "Verification code resent to new address"}

    async def refresh_access_token(self, refresh_token: str):
        payload = Security.decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )

        token_hash = Security.hash_token(refresh_token)
        db_token = await self.rt_repo.get_by_token_hash(token_hash)
        if not db_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )

        # Rotate: revoke old, issue new
        await self.rt_repo.revoke(token_hash)

        user_id = payload.get("sub")
        new_access_token = Security.create_access_token(user_id)
        new_refresh_token = Security.create_refresh_token(user_id)

        new_token_hash = Security.hash_token(new_refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, new_token_hash, refresh_expires)

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer"
        }

    async def logout_user(self, refresh_token: str):
        token_hash = Security.hash_token(refresh_token)
        await self.rt_repo.revoke(token_hash)
        return {"message": "User logged out successfully"}

    @staticmethod
    def _check_resend_rate_limit(db_user):
        if db_user.last_code_sent_at:
            one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
            if db_user.last_code_sent_at > one_hour_ago and db_user.code_resend_count >= MAX_RESEND_PER_HOUR:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many code requests, please try again later"
                )

    @staticmethod
    def _compute_resend_count(db_user, now: datetime) -> int:
        one_hour_ago = now - timedelta(hours=1)
        if db_user.last_code_sent_at and db_user.last_code_sent_at > one_hour_ago:
            return db_user.code_resend_count + 1
        return 1
