from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel
from jose import jwt
import requests

from core.database import get_db
from models.user import User
from schemas.auth import UserCreate, UserLogin, UserResponse, Token, UserUpdate
from schemas.dexcom import DexcomCredentials, DexcomResponse
from services.auth import create_access_token, verify_password, get_password_hash, get_current_user
from fastapi import Body
from utils.logging import get_logger
from utils.encryption import encrypt_password

# Ensure router exists before any decorator usage
router = APIRouter()

logger = get_logger(__name__)
security = HTTPBearer()

# --- Social Login Schema ---
class SocialLoginRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    provider: str  # 'google' or 'apple'
    id_token: str

@router.post("/social-login", response_model=Token)
async def social_login(
    data: SocialLoginRequest,
    db: Session = Depends(get_db)
):
    """Authenticate or register user via Google/Apple sign-in and return tokens"""
    logger.info(f"Social login attempt: {data.email} via {data.provider}")

    # 1. Verify id_token with provider
    if data.provider == 'google':
        google_url = f'https://oauth2.googleapis.com/tokeninfo?id_token={data.id_token}'
        resp = requests.get(google_url)
        if resp.status_code != 200:
            logger.warning(f"Google token verification failed for {data.email}")
            raise HTTPException(status_code=401, detail="Invalid Google token")
        token_info = resp.json()
        email_verified = token_info.get('email_verified') == 'true'
        if not email_verified or token_info.get('email') != data.email:
            logger.warning(f"Google email mismatch or not verified: {data.email}")
            raise HTTPException(status_code=401, detail="Google email not verified")
    elif data.provider == 'apple':
        # Apple token verification (basic, for production use Apple public keys)
        try:
            decoded = jwt.get_unverified_claims(data.id_token)
            if decoded.get('email') != data.email:
                logger.warning(f"Apple email mismatch: {data.email}")
                raise HTTPException(status_code=401, detail="Apple email mismatch")
        except Exception as e:
            logger.warning(f"Apple token decode failed: {e}")
            raise HTTPException(status_code=401, detail="Invalid Apple token")
    else:
        raise HTTPException(status_code=400, detail="Unsupported provider")

    # 2. Find or create user
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        user = User(
            username=data.email,
            email=data.email,
            first_name=data.first_name,
            last_name=data.last_name,
            is_active=True,
            is_verified=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        logger.info(f"Created new user via social login: {data.email}")
    else:
        # Update names if changed
        updated = False
        if user.first_name != data.first_name:
            user.first_name = data.first_name
            updated = True
        if user.last_name != data.last_name:
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

    # 3. Issue tokens
    access_token = create_access_token(data={"sub": user.username})
    refresh_token = create_access_token(data={"sub": user.username, "type": "refresh"}, expires_delta=timedelta(days=7))
    user.refresh_token = refresh_token
    db.commit()

    logger.info(f"Social login successful for {user.email}")
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": 1800
    }

@router.post("/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    logger.info(f"User registration attempt: {user_data.username}")
    
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        logger.warning(f"Registration failed - username exists: {user_data.username}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    
    # Check if email already exists
    existing_email = db.query(User).filter(User.email == user_data.email).first()
    if existing_email:
        logger.warning(f"Registration failed - email exists: {user_data.email}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    user = User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password,
        first_name=user_data.first_name,
        last_name=user_data.last_name
    )
    
    db.add(user)
    db.commit()
    db.refresh(user)
    
    logger.info(f"User registered successfully: {user.username}")
    return user

@router.post("/login", response_model=Token)
async def login(user_credentials: UserLogin, db: Session = Depends(get_db)):
    """Authenticate user and return access and refresh tokens"""
    logger.info(f"Login attempt: {user_credentials.username}")

    # Find user by username
    user = db.query(User).filter(User.username == user_credentials.username).first()

    # Verify credentials
    if not user or not verify_password(user_credentials.password, user.hashed_password):
        logger.warning(f"Login failed - invalid credentials: {user_credentials.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        logger.warning(f"Login failed - inactive user: {user_credentials.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Inactive user account"
        )

    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()

    # Create access and refresh tokens
    access_token = create_access_token(data={"sub": user.username})
    refresh_token = create_access_token(data={"sub": user.username, "type": "refresh"}, expires_delta=timedelta(days=7))

    # Ensure both tokens are present
    if not access_token or not refresh_token:
        logger.error(f"Login failed: Missing token(s) for user {user.username}. access_token: {bool(access_token)}, refresh_token: {bool(refresh_token)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate authentication tokens. Please try again later."
        )

    # Store refresh token in user model (add field if not present)
    user.refresh_token = refresh_token
    db.commit()

    logger.info(f"User logged in successfully: {user.username}")
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": 1800  # 30 minutes
    }

@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Get current user profile"""
    return current_user


# PATCH /me endpoint to update current user profile
@router.patch("/me", response_model=UserResponse)
async def update_current_user_profile(
    update: UserUpdate = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update current user profile"""
    # Only update fields present in the request
    update_data = update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    logger.info(f"User profile updated: {current_user.username}")
    return current_user


class RefreshRequest(BaseModel):
    refresh_token: str

@router.post("/refresh", response_model=Token)
async def refresh_token(
    body: RefreshRequest,
    db: Session = Depends(get_db)
):
    """Refresh access token using refresh token"""
    from services.auth import verify_token
    refresh_token = body.refresh_token
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        logger.info("Refresh attempt received")
        payload = verify_token(refresh_token, credentials_exception)
        username = payload.username
        user = db.query(User).filter(User.username == username).first()
        if not user:
            logger.warning(f"No user found for username: {username}")
        if not user or user.refresh_token != refresh_token:
            logger.warning(f"Refresh token mismatch for user {username if user else 'unknown'}")
            raise credentials_exception
        # Issue new access and refresh tokens (rotate refresh token)
        access_token = create_access_token(data={"sub": user.username})
        new_refresh_token = create_access_token(data={"sub": user.username, "type": "refresh"}, expires_delta=timedelta(days=7))
        user.refresh_token = new_refresh_token
        db.commit()
        logger.info(f"Refresh successful for user {username}")
        return {
            "access_token": access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
            "expires_in": 1800
        }
    except Exception as e:
        logger.error(f"Refresh failed: {e}")
        raise credentials_exception

@router.delete('/delete-account')
async def delete_account(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Delete the current user's account and associated data."""
    try:
        # TODO: cascade delete related records (glucose, insulin, recommendations, etc.)
        db.delete(current_user)
        db.commit()
        logger.info("Account deleted for user")
        return {"success": True}
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete account")

@router.post("/connect-dexcom", response_model=DexcomResponse)
async def connect_dexcom(
    credentials: DexcomCredentials,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Connect Dexcom account to user profile"""
    try:
        # Encrypt password
        encrypted_password = encrypt_password(credentials.password)
        
        # Update user's Dexcom credentials
        current_user.dexcom_username = credentials.username
        current_user.dexcom_password = encrypted_password
        current_user.dexcom_ous = credentials.ous
        
        # Save to database
        db.commit()
        
        logger.info(f"Dexcom account connected for user: {current_user.username}")
        return {
            "success": True,
            "message": "Dexcom account connected successfully"
        }
    except Exception as e:
        logger.error(f"Failed to connect Dexcom: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to connect Dexcom account"
        )
