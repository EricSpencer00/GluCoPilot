from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    """Application settings"""
    
    # Environment
    DEBUG: bool = True
    ENVIRONMENT: str = "development"
    
    # Database
    DATABASE_URL: str = "sqlite:///backend/glucopilot.db"
    DATABASE_ECHO: bool = False
    # Allow disabling DB usage for stateless deployments
    USE_DATABASE: bool = os.getenv("USE_DATABASE", "false").lower() in ("1", "true", "yes")
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-this-in-production")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Apple Sign In
    APPLE_CLIENT_ID: str = os.getenv("APPLE_CLIENT_ID", "")
    
    # Dexcom Official API (OAuth2)
    DEXCOM_CLIENT_ID: str = os.getenv("DEXCOM_CLIENT_ID", "")
    DEXCOM_CLIENT_SECRET: str = os.getenv("DEXCOM_CLIENT_SECRET", "")
    DEXCOM_REDIRECT_URI: str = os.getenv("DEXCOM_REDIRECT_URI", "")
    DEXCOM_ENV: str = os.getenv("DEXCOM_ENV", "sandbox")  # 'sandbox' or 'production'
    DEXCOM_API_BASE: str = os.getenv(
        "DEXCOM_API_BASE",
        "https://sandbox-api.dexcom.com"  # production: https://api.dexcom.com
    )
    
    # API Configuration
    API_HOST: str = "0.0.0.0"  # Allow connections from any IP
    API_PORT: int = 8000
    CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "*")
    
    # Dexcom legacy (pydexcom) placeholders
    DEXCOM_USERNAME: str = ""
    DEXCOM_PASSWORD: str = ""
    DEXCOM_OUS: bool = False
    
    # AI/ML
    HUGGINGFACE_TOKEN: str = ""
    LOCAL_MODEL_PATH: str = "./models/"
    USE_LOCAL_MODEL: bool = False
    USE_REMOTE_MODEL: bool = True
    MODEL_NAME: str = "microsoft/DialoGPT-medium"
    
    # Reddit
    REDDIT_CLIENT_ID: str = ""
    REDDIT_CLIENT_SECRET: str = ""
    REDDIT_USER_AGENT: str = "GluCoPilot/1.0.0"
    
    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "./logs/glucopilot.log"
    
    # Data Processing
    GLUCOSE_SYNC_INTERVAL: int = 300  # 5 minutes
    PATTERN_ANALYSIS_INTERVAL: int = 3600  # 1 hour
    REDDIT_SYNC_INTERVAL: int = 86400  # 24 hours
    
    # Cache
    CACHE_TTL: int = 3600  # 1 hour
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # HealthKit: No backend bridge needed, data is local-only
    # If you want to sync HealthKit data to backend in future, add a bridge URL here
    # HEALTHKIT_BRIDGE_URL: str = ""
    
    # Expo Mobile App
    EXPO_APP_ID: str = "f16e8675-cf9b-4b3d-a4ba-58b21d990311"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore extra fields from environment

settings = Settings()

# Basic production safety checks
if settings.ENVIRONMENT.lower() == 'production':
    if settings.SECRET_KEY == "your-secret-key-change-this-in-production":
        raise RuntimeError("SECRET_KEY must be set in production")
    if settings.CORS_ORIGINS == "*":
        settings.CORS_ORIGINS = ""
