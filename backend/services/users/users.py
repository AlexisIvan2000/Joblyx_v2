from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from core.security import Security
from models.schemas import UpdateProfile
from repositories.auth_repository import AuthRepository
from services.emailing.otp_service import OtpService

MAX_VERIFICATION_ATTEMPTS = 5


class UserService:
    def __init__(self, auth_repo: AuthRepository, otp_service: OtpService):
        self.repo = auth_repo
        self.otp_svc = otp_service

    async def update_profile(self, user_id: str, data: UpdateProfile):
        data_dict = data.model_dump(exclude_none=True)
        if not data_dict:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update"
            )
        await self.repo.update_user(user_id, data_dict)
        return {"message": "Profile updated successfully"}

    async def change_password(self, user_id: str, current_password: str, new_password: str):
        db_user = await self.repo.get_user_by_id(user_id)
        if not Security.verify_password(db_user.password_hash, current_password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current password is incorrect"
            )
        new_hash = Security.hash_password(new_password)
        await self.repo.update_user(user_id, {"password_hash": new_hash})
        return {"message": "Password changed successfully"}

    async def forgot_password(self, email: str):
        db_user = await self.repo.get_user_by_email(email)
        if db_user:
            await self.otp_svc.send_reset_otp(email)
        return {"message": "If this email is registered, a reset code has been sent"}

    async def reset_password(self, email: str, code: str, new_password: str):
        db_user = await self.repo.get_user_by_email(email)
        if not db_user or not db_user.reset_code_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset code"
            )

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many attempts, request a new code"
            )

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.reset_code_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid reset code"
            )

        expires_at = db_user.reset_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reset code has expired"
            )

        new_hash = Security.hash_password(new_password)
        await self.repo.update_password(str(db_user.id), new_hash)
        return {"message": "Password reset successfully"}

    async def request_email_change(self, user_id: str, new_email: str, password: str):
        db_user = await self.repo.get_user_by_id(user_id)
        if not Security.verify_password(db_user.password_hash, password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid password"
            )
        if await self.repo.get_user_by_email(new_email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use"
            )

        await self.repo.update_user(user_id, {"pending_email": new_email})
        await self.otp_svc.send_email_change_otp(new_email, user_id)
        return {"message": "Verification code sent to new address"}

    async def confirm_email_change(self, user_id: str, code: str):
        db_user = await self.repo.get_user_by_id(user_id)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User not found"
            )

        pending_email = db_user.pending_email
        if not pending_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No pending email change"
            )

        if not db_user.email_change_code_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No email change code found"
            )

        if db_user.verification_attempts >= MAX_VERIFICATION_ATTEMPTS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many attempts, request a new code"
            )

        await self.repo.increment_verification_attempts(str(db_user.id))

        code_hash = Security.hash_token(code)
        if code_hash != db_user.email_change_code_hash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification code"
            )

        expires_at = db_user.email_change_code_expires_at
        if expires_at and expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verification code expired. Please request a new one."
            )

        await self.repo.update_user(str(db_user.id), {
            "email": pending_email,
            "pending_email": None,
            "email_change_code_hash": None,
            "email_change_code_expires_at": None,
            "verification_attempts": 0,
        })
        return {"message": "Email changed successfully"}
