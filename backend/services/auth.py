from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from models.user import User
from schemas.auth import TokenData
from utils.logging import get_logger

logger = get_logger(__name__)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT settings
ALGORITHM = "HS256"
security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str, credentials_exception):
    """Verify JWT token and extract username"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    return token_data

class SimpleUser:
    def __init__(self, username: str):
        self.username = username
        self.email = username
        self.is_active = True
        self.is_verified = True
        self.id = None

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Get current authenticated user. In stateless mode, return a simple identity without DB lookup."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    token_data = verify_token(credentials.credentials, credentials_exception)

    if not settings.USE_DATABASE:
        # Stateless: don't hit DB
        return SimpleUser(username=token_data.username)

    user = db.query(User).filter(User.username == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user


async def get_optional_current_user(request: Request, db: Session = Depends(get_db)):
    """Return current user if Authorization Bearer token is present and valid, else None.
    This helper reads the Authorization header directly to avoid raising HTTP errors when no token is provided.
    """
    from fastapi import Request
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    auth_header = request.headers.get('authorization') or request.headers.get('Authorization')
    if not auth_header:
        return None
    if not auth_header.lower().startswith('bearer '):
        return None
    token = auth_header.split(' ', 1)[1]
    try:
        token_data = verify_token(token, credentials_exception)
    except Exception:
        return None

    if not settings.USE_DATABASE:
        # Stateless: return a simple identity
        return SimpleUser(username=token_data.username)

    user = db.query(User).filter(User.username == token_data.username).first()
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    """Get current active user"""
    if not getattr(current_user, 'is_active', True):
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user
