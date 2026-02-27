import secrets
from fastapi import HTTPException, status
from models.schemas import UserCreate, UserLogin, UpdateProfile
from core.security import Security
from repositories.auth_repository import AuthRepository
from services.emailing.email_sender import EmailSender
from datetime import datetime, timedelta, timezone

class EmailPasswordAuth:
    def __init__(self, auth_repo: AuthRepository):
        self.repo = auth_repo

    def register_user(self, user: UserCreate):
        if self.repo.get_user_by_email(user.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        hashed_password = Security.hash_password(user.password)
        new_user = self.repo.create_user({
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "password_hash": hashed_password
        })
        user_id = str(new_user["id"])
        verification_token = secrets.token_urlsafe(32)
        verification_token_expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
        self.repo.update_user(user_id, {
            "verification_token": verification_token,
            "verification_token_expires_at": verification_token_expires_at.isoformat()
        })
        EmailSender().send_verification_email(user.email, token=verification_token)
        access_token = Security.create_access_token(user_id)
        refresh_token = Security.create_refresh_token(user_id)
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    def login_user(self, user: UserLogin):
        db_user = self.repo.get_user_by_email(user.email)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        if not Security.verify_password(db_user["password_hash"], user.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        if not db_user.get("is_verified"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email before logging in"
            )
        user_id = str(db_user["id"])
        access_token = Security.create_access_token(user_id)
        refresh_token = Security.create_refresh_token(user_id)
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    def verify_email(self, token: str):
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
        user_id = str(db_user["id"])
        pending_email = db_user.get("pending_email")
        if pending_email:
            self.repo.update_user(user_id, {
                "email": pending_email,
                "pending_email": None,
                "is_verified": True,
                "verification_token": None,
                "verification_token_expires_at": None,
            })
            return {"message": "Email changed and verified successfully"}
        self.repo.update_verification_status(user_id)
        return {"message": "Email verified successfully"}

    def resend_verification_email(self, email: str):
        db_user = self.repo.get_user_by_email(email)
        if db_user and not db_user.get("is_verified"):
            verification_token = secrets.token_urlsafe(32)
            verification_token_expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
            self.repo.update_user(str(db_user["id"]), {
                "verification_token": verification_token,
                "verification_token_expires_at": verification_token_expires_at,
            })
            EmailSender().send_verification_email(email, token=verification_token)
        return {"message": "If this email is registered and unverified, a new verification link has been sent"}

    def resend_email_change_verification(self, user_id: str):
        db_user = self.repo.get_user_by_id(user_id)
        pending_email = db_user.get("pending_email")
        if not pending_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No pending email change"
            )
        verification_token = secrets.token_urlsafe(32)
        verification_token_expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
        self.repo.update_user(user_id, {
            "verification_token": verification_token,
            "verification_token_expires_at": verification_token_expires_at,
        })
        EmailSender().send_verification_email(pending_email, token=verification_token)
        return {"message": "Verification email resent to new address"}

    def refresh_access_token(self, refresh_token: str):
        payload = Security.decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )
        user_id = payload.get("sub")
        new_access_token = Security.create_access_token(user_id)
        return {
            "access_token": new_access_token,
            "token_type": "bearer"
        }

    def logout_user(self, refresh_token: str):
        # TODO: Implement token invalidation (e.g. blacklist in DB or Redis)
        return {"message": "User logged out successfully"}

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
