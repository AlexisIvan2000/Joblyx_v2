import resend
from core.config import RESEND_API_KEY, RESEND_FROM_EMAIL, FRONTEND_URL, RESEND_FROM_NAME
from typing import Dict

class EmailSender:

    def __init__(self):
        resend.api_key = RESEND_API_KEY

    def send_verification_email(self, to: str, token: str) -> Dict:
        verify_link = f"{FRONTEND_URL}/verify-email?token={token}"
        subject = "Email verification"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Welcome to Joblyx</h2> 
                    <p>Thank you for registering with Joblyx! Please click the link below to verify your email address and complete your registration.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{verify_link}" style="background-color: #4db6ac; color: #ffffff; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-size: 16px; display: inline-block;">Verify Email</a>
                    </div>
                    <p>This link will expire in 24 hours. Do not reply to this email</p>
                    <p>If you did not create an account, please ignore this email.</p>
                    <p style="color: #888; font-size: 12px; text-align: center;">&copy; 2026 Joblyx. All rights reserved.</p>
                </div>
            """
        params = {
            "from": f"{RESEND_FROM_NAME} <{RESEND_FROM_EMAIL}>",
            "to": [to],
            "subject": subject,
            "html": html
        }
        response = resend.Emails.send(params)
        return response

    def send_reset_password_email(self, to: str, token: str) -> Dict:
        reset_link = f"{FRONTEND_URL}/reset-password?token={token}"
        subject = "Password reset"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Password Reset Request</h2> 
                    <p>We received a request to reset your password. Please click the link below to set a new password for your account.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{reset_link}" style="background-color: #4db6ac; color: #ffffff; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-size: 16px; display: inline-block;">Reset Password</a>
                    </div>
                    <p>This link will expire in 1 hour. Do not reply to this email</p>
                    <p>If you did not request a password reset, please ignore this email.</p>
                    <p>Thank you,<br/>The Joblyx Team</p>
                </div>
            """
        params = {
            "from": f"{RESEND_FROM_NAME} <{RESEND_FROM_EMAIL}>",
            "to": [to],
            "subject": subject,
            "html": html
        }
        response = resend.Emails.send(params)
        return response
