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
    email: str | None = None
    provider: str  # 'apple' or 'google' (apple preferred)
    id_token: str

@router.post("/social-login", response_model=Token)
async def social_login(
    data: SocialLoginRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Authenticate via Apple/Google. If USE_DATABASE is False, do not persist users; just mint app JWT."""
    logger.info(f"Social login attempt: {data.email or '[no email]'} via {data.provider}")

    apple_user_id = None
    if data.provider == 'apple':
        logger.info(f"Apple id_token: {credentials.credentials}")
        claims = verify_apple_token(credentials.credentials, audience=settings.APPLE_CLIENT_ID or None)
        logger.info(f"Apple token claims: {claims}")
        apple_user_id = claims.get('sub')
        # Only check email match if both are present
        if claims.get("email") and data.email:
            if claims["email"].lower() != data.email.lower():
                raise HTTPException(status_code=401, detail="Apple email mismatch")
        # If no email provided, set from claims if available
        if not data.email and claims.get("email"):
            data.email = claims["email"]
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
        subject = data.email or apple_user_id
        access_token = create_access_token(data={"sub": subject})
        refresh_token = create_access_token(data={"sub": subject, "type": "refresh"}, expires_delta=timedelta(days=7))
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 1800
        }

    # Otherwise, persist/update user in DB
    user = None
    if data.provider == 'apple':
        # Try to find user by email first, then by Apple user ID (sub)
        if data.email:
            user = db.query(User).filter(User.email == data.email).first()
        if not user and apple_user_id:
            user = db.query(User).filter(User.username == apple_user_id).first()
    else:
        if data.email:
            user = db.query(User).filter(User.email == data.email).first()

    if not user:
        # For Apple, use sub as username if available
        username = apple_user_id if data.provider == 'apple' and apple_user_id else (data.email or "")
        user = User(
            username=username,
            email=data.email or "",
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
    """Connect Dexcom account to user profile (if DB enabled). Deprecated for stateless deployments.

    In stateless mode, storing third-party credentials on the server is disabled. Use the
    stateless endpoints under `/api/v1/glucose/stateless/*` which accept credentials per-call
    and do not persist them on the server. This avoids storing Dexcom passwords and simplifies
    compliance and deployment.
    """
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Deprecated in stateless mode. Use /api/v1/glucose/stateless/sync or /api/v1/glucose/stateless/latest instead.")

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

@router.get('/me')
async def get_me(current_user: User = Depends(get_current_user)):
    """Return current user profile. In stateless mode return a minimal payload so clients can use it."""
    # If DB is enabled, current_user will be a User instance and is suitable to return
    if settings.USE_DATABASE:
        return current_user

    # Stateless mode: current_user is a SimpleUser with minimal attributes.
    # Construct a minimal response compatible with frontend expectations (id and email at minimum).
    return {
        "id": 0,
        "username": getattr(current_user, "username", ""),
        "email": getattr(current_user, "email", getattr(current_user, "username", "")),
        "first_name": getattr(current_user, "first_name", ""),
        "last_name": getattr(current_user, "last_name", ""),
        "is_active": getattr(current_user, "is_active", True),
        "is_verified": getattr(current_user, "is_verified", True),
        "created_at": datetime.utcnow(),
        "last_login": None,
        "target_glucose_min": None,
        "target_glucose_max": None,
        "insulin_carb_ratio": None,
        "insulin_sensitivity_factor": None,
    }
