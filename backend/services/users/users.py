import secrets
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from core.security import Security
from models.schemas import UpdateProfile
from repositories.auth_repository import AuthRepository
from services.emailing.email_sender import EmailSender


class UserService:
    def __init__(self, auth_repo: AuthRepository):
        self.repo = auth_repo

    def update_profile(self, user_id: str, data: UpdateProfile):
        data_dict = data.model_dump(exclude_none=True)
        if not data_dict:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update"
            )
        self.repo.update_user(user_id, data_dict)
        return {"message": "Profile updated successfully"}

    def change_password(self, user_id: str, current_password: str, new_password: str):
        db_user = self.repo.get_user_by_id(user_id)
        if not Security.verify_password(db_user["password_hash"], current_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect"
            )
        new_hash = Security.hash_password(new_password)
        self.repo.update_user(user_id, {"password_hash": new_hash})
        return {"message": "Password changed successfully"}

    def forgot_password(self, email: str):
        db_user = self.repo.get_user_by_email(email)
        if db_user:
            token = secrets.token_urlsafe(32)
            expires_at = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
            self.repo.save_reset_token(email, token, expires_at)
            EmailSender().send_reset_password_email(email, token)
        return {"message": "If this email is registered, a reset link has been sent"}

    def reset_password(self, token: str, new_password: str):
        db_user = self.repo.get_user_by_reset_token(token)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset token"
            )
        expires_at = db_user.get("reset_token_expires_at")
        if expires_at and expires_at < datetime.now(timezone.utc).isoformat():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reset token has expired"
            )
        new_hash = Security.hash_password(new_password)
        self.repo.update_password(str(db_user["id"]), new_hash)
        return {"message": "Password reset successfully"}

    def confirm_email_change(self, token: str):
        db_user = self.repo.get_user_by_verification_token(token)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification token"
            )
        expires_at = db_user.get("verification_token_expires_at")
        if expires_at and expires_at < datetime.now(timezone.utc).isoformat():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verification token expired. Please request a new one."
            )
        pending_email = db_user.get("pending_email")
        if not pending_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No pending email change"
            )
        user_id = str(db_user["id"])
        self.repo.update_user(user_id, {
            "email": pending_email,
            "pending_email": None,
            "verification_token": None,
            "verification_token_expires_at": None,
        })
        return {"message": "Email changed successfully"}

    def request_email_change(self, user_id: str, new_email: str, password: str):
        db_user = self.repo.get_user_by_id(user_id)
        if not Security.verify_password(db_user["password_hash"], password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid password"
            )
        if self.repo.get_user_by_email(new_email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use"
            )
        verification_token = secrets.token_urlsafe(32)
        verification_token_expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
        self.repo.update_user(user_id, {
            "pending_email": new_email,
            "verification_token": verification_token,
            "verification_token_expires_at": verification_token_expires_at,
        })
        EmailSender().send_verification_email(new_email, token=verification_token)
        return {"message": "Verification email sent to new address"}
