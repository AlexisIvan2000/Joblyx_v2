from fastapi import HTTPException, status
from models.schemas import UserCreate, UserLogin
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.emailing.otp_service import OtpService
from datetime import datetime, timedelta, timezone

MAX_VERIFICATION_ATTEMPTS = 5


class EmailPasswordAuth:
    def __init__(self, auth_repo: AuthRepository, refresh_token_repo: RefreshTokenRepository, otp_service: OtpService):
        self.repo = auth_repo
        self.rt_repo = refresh_token_repo
        self.otp_svc = otp_service

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

        await self.otp_svc.send_verification_otp(user.email, str(new_user.id))

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
            await self.otp_svc.send_verification_otp(email, str(db_user.id), db_user=db_user)
        return {"message": "If this email is registered and unverified, a new verification code has been sent"}

    async def resend_email_change_verification(self, user_id: str):
        db_user = await self.repo.get_user_by_id(user_id)
        pending_email = db_user.pending_email
        if not pending_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No pending email change"
            )

        await self.otp_svc.send_email_change_otp(pending_email, user_id, db_user=db_user)
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
