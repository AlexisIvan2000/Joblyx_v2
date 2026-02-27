import resend
from core.config import RESEND_API_KEY, RESEND_FROM_EMAIL, FRONTEND_URL
from typing import Dict

class EmailSender:
    
    def __init__(self):
        self.client = resend.Resend(RESEND_API_KEY)
    
    def send_verification_email(self, to: str, token: str) -> Dict:
        verify_link = f"{FRONTEND_URL}/verify-email?token={token}"
        subject = "Email verification"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Welcome to Joblyx</h2> 
                    <p>Thank you for registering with Joblyx! Please click the link below to verify your email address and complete your registration.</p>
                    <a href="{verify_link}">Verify Email</a>
                    <p>This link will expire in 24 hours.</p>
                    <p>If you did not create an account, please ignore this email.</p>
                    <p style="color: #888; font-size: 12px; text-align: center;">&copy; 2026 Joblyx. All rights reserved.</p>
                </div>
            """
        params = {
            "from": RESEND_FROM_EMAIL,
            "to": [to],
            "subject": subject,
            "html": html
        }
        response = self.client.emails.send(params)
        return response
    
    def send_reset_password_email(self, to: str, token: str) -> Dict:
        reset_link = f"{FRONTEND_URL}/reset-password?token={token}"
        subject = "Password reset"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Password Reset Request</h2> 
                    <p>We received a request to reset your password. Please click the link below to set a new password for your account.</p>
                    <a href="{reset_link}">Reset Password</a>
                    <p>This link will expire in 1 hour.</p>
                    <p>If you did not request a password reset, please ignore this email.</p>
                    <p>Thank you,<br/>The Joblyx Team</p>
                </div>
            """
        params = {
            "from": RESEND_FROM_EMAIL,
            "to": [to],
            "subject": subject,
            "html": html
        }
        response = self.client.emails.send(params)
        return response
          
