import resend
from core.config import RESEND_API_KEY, RESEND_FROM_EMAIL, RESEND_FROM_NAME
from typing import Dict

class EmailSender:

    def __init__(self):
        resend.api_key = RESEND_API_KEY

    def send_verification_email(self, to: str, code: str) -> Dict:
        subject = "Email verification"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Welcome to Joblyx</h2>
                    <p>Thank you for registering with Joblyx! Use the code below to verify your email address and complete your registration.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="background-color: #f5f5f5; color: #333; padding: 16px 32px; font-size: 32px; font-weight: bold; letter-spacing: 8px; border-radius: 8px; display: inline-block;">{code}</span>
                    </div>
                    <p>This code will expire in 15 minutes. Do not reply to this email.</p>
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

    def send_reset_password_email(self, to: str, code: str) -> Dict:
        subject = "Password reset"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Password Reset Request</h2>
                    <p>We received a request to reset your password. Use the code below to set a new password for your account.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="background-color: #f5f5f5; color: #333; padding: 16px 32px; font-size: 32px; font-weight: bold; letter-spacing: 8px; border-radius: 8px; display: inline-block;">{code}</span>
                    </div>
                    <p>This code will expire in 15 minutes. Do not reply to this email.</p>
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

    def send_email_change_email(self, to: str, code: str) -> Dict:
        subject = "Email change verification"
        html = f"""
                <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #4db6ac; text-align: center; font-size: 24px;">Email Change Request</h2>
                    <p>We received a request to change the email address on your Joblyx account. Use the code below to confirm this change.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="background-color: #f5f5f5; color: #333; padding: 16px 32px; font-size: 32px; font-weight: bold; letter-spacing: 8px; border-radius: 8px; display: inline-block;">{code}</span>
                    </div>
                    <p>This code will expire in 15 minutes. Do not reply to this email.</p>
                    <p>If you did not request this change, please ignore this email.</p>
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
