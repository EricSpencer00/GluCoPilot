from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel
import requests

from core.database import get_db
from models.user import User
from schemas.auth import UserCreate, UserLogin, UserResponse, Token, UserUpdate
from schemas.dexcom import DexcomCredentials, DexcomResponse
from services.auth import create_access_token, verify_password, get_password_hash, get_current_user
from services.auth_apple import verify_apple_token
from fastapi import Body
from utils.logging import get_logger
from utils.encryption import encrypt_password
from core.config import settings

# Ensure router exists before any decorator usage
router = APIRouter()

logger = get_logger(__name__)
security = HTTPBearer()

# --- Social Login Schema ---
class SocialLoginRequest(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    email: str
    provider: str  # 'apple' or 'google' (apple preferred)
    id_token: str

@router.post("/social-login", response_model=Token)
async def social_login(
    data: SocialLoginRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Authenticate via Apple/Google. If USE_DATABASE is False, do not persist users; just mint app JWT."""
    logger.info(f"Social login attempt: {data.email} via {data.provider}")

    if data.provider == 'apple':
        claims = verify_apple_token(credentials.credentials, audience=settings.APPLE_CLIENT_ID or None)
        if claims.get("email") and claims["email"].lower() != data.email.lower():
            raise HTTPException(status_code=401, detail="Apple email mismatch")
    else:
        # Basic Google id_token verification for compatibility
        token = data.id_token
        if token and '.' in token:
            google_url = f'https://oauth2.googleapis.com/tokeninfo?id_token={token}'
            resp = requests.get(google_url, timeout=5)
            if resp.status_code != 200:
                raise HTTPException(status_code=401, detail="Invalid Google id_token")
            token_info = resp.json()
            email_verified = token_info.get('email_verified') in (True, 'true', 'True')
            if not email_verified or token_info.get('email', '').lower() != data.email.lower():
                raise HTTPException(status_code=401, detail="Google email not verified")
            if not data.first_name and token_info.get('given_name'):
                data.first_name = token_info.get('given_name')
            if not data.last_name and token_info.get('family_name'):
                data.last_name = token_info.get('family_name')
        else:
            raise HTTPException(status_code=400, detail="Unsupported token format for Google")

    # If stateless, mint app token without DB
    if not settings.USE_DATABASE:
        subject = data.email
        access_token = create_access_token(data={"sub": subject})
        refresh_token = create_access_token(data={"sub": subject, "type": "refresh"}, expires_delta=timedelta(days=7))
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 1800
        }

    # Otherwise, persist/update user in DB
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        user = User(
            username=data.email,
            email=data.email,
            first_name=data.first_name or "",
            last_name=data.last_name or "",
            is_active=True,
            is_verified=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        updated = False
        if data.first_name and user.first_name != data.first_name:
            user.first_name = data.first_name
            updated = True
        if data.last_name and user.last_name != data.last_name:
            user.last_name = data.last_name
            updated = True
        if not user.is_active:
            user.is_active = True
            updated = True
        if not user.is_verified:
            user.is_verified = True
            updated = True
        if updated:
            db.commit()

    access_token = create_access_token(data={"sub": user.username})
    refresh_token = create_access_token(data={"sub": user.username, "type": "refresh"}, expires_delta=timedelta(days=7))
    user.refresh_token = refresh_token
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": 1800
    }

# Keep Dexcom connect endpoint after auth
@router.post("/connect-dexcom", response_model=DexcomResponse)
async def connect_dexcom(
    credentials: DexcomCredentials,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Connect Dexcom account to user profile (if DB enabled). If stateless, reject storing passwords."""
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=400, detail="Dexcom credential storage disabled in stateless mode")
    try:
        encrypted_password = encrypt_password(credentials.password)
        current_user.dexcom_username = credentials.username
        current_user.dexcom_password = encrypted_password
        current_user.dexcom_ous = credentials.ous
        db.commit()
        return {"success": True, "message": "Dexcom account connected successfully"}
    except Exception as e:
        logger.error(f"Failed to connect Dexcom: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to connect Dexcom account")
