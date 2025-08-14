
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from core.database import get_db
from models.user import User
from services.auth import get_password_hash
from utils.logging import get_logger
import smtplib
from email.message import EmailMessage
import secrets
import os

router = APIRouter()
logger = get_logger(__name__)

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


def send_reset_email(to_email: str, reset_link: str):
    smtp_host = os.environ.get("SMTP_HOST", "localhost")
    smtp_port = int(os.environ.get("SMTP_PORT", 1025))
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_pass = os.environ.get("SMTP_PASS", "")
    from_email = os.environ.get("FROM_EMAIL", "noreply@glucopilot.ai")

    msg = EmailMessage()
    msg["Subject"] = "GluCoPilot Password Reset"
    msg["From"] = from_email
    msg["To"] = to_email
    msg.set_content(f"""
Hello,

We received a request to reset your GluCoPilot password. If you did not request this, you can ignore this email.

To reset your password, click the link below:
{reset_link}

This link will expire in 1 hour.

Best,
GluCoPilot Team
""")

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        if smtp_user and smtp_pass:
            server.starttls()
            server.login(smtp_user, smtp_pass)
        server.send_message(msg)

@router.post("/forgot-password")
async def forgot_password(
    request: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Handle forgot password request by sending reset instructions if user exists."""
    user = db.query(User).filter(User.email == request.email).first()
    if user:
        # Generate a secure token (simulate, not stored)
        token = secrets.token_urlsafe(32)
        reset_link = f"https://glucopilot.ai/reset-password?token={token}"
        logger.info(f"Password reset requested for user: {user.email}")
        background_tasks.add_task(send_reset_email, user.email, reset_link)
    else:
        logger.info(f"Password reset requested for non-existent email: {request.email}")
    # Always return success to prevent email enumeration
    return {"message": "If an account exists for this email, reset instructions have been sent."}
