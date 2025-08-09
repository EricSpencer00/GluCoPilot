from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from core.database import get_db
from models.user import User
from schemas.auth import UserCreate, UserLogin, UserResponse, Token
from schemas.dexcom import DexcomCredentials, DexcomResponse
from services.auth import create_access_token, verify_password, get_password_hash, get_current_user
from utils.logging import get_logger
from utils.encryption import encrypt_password

logger = get_logger(__name__)
router = APIRouter()
security = HTTPBearer()

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


from pydantic import BaseModel

class RefreshRequest(BaseModel):
    refresh_token: str

@router.post("/refresh", response_model=Token)
async def refresh_token(
    body: RefreshRequest,
    db: Session = Depends(get_db)
):
    """Refresh access token using refresh token"""
    from services.auth import verify_token
    import logging
    refresh_token = body.refresh_token
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        logging.info(f"Refresh attempt with token: {refresh_token}")
        payload = verify_token(refresh_token, credentials_exception)
        username = payload.username
        user = db.query(User).filter(User.username == username).first()
        if not user:
            logging.warning(f"No user found for username: {username}")
        if not user or user.refresh_token != refresh_token:
            logging.warning(f"Refresh token mismatch for user {username if user else 'unknown'}")
            raise credentials_exception
        # Issue new access token
        access_token = create_access_token(data={"sub": user.username})
        logging.info(f"Refresh successful for user {username}")
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 1800
        }
    except Exception as e:
        logging.error(f"Refresh failed: {e}")
        raise credentials_exception

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
