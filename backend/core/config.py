from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    """Application settings"""
    
    # Environment
    DEBUG: bool = True
    ENVIRONMENT: str = "development"
    
    # Database
    DATABASE_URL: str = "postgresql+psycopg2://glucopilot:glucopilot@localhost:5432/glucopilot"
    DATABASE_ECHO: bool = False
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # API Configuration
    API_HOST: str = "0.0.0.0"  # Allow connections from any IP
    API_PORT: int = 8000
    # CORS_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:19006,exp://,http://192.168.1.36:8000,exp://192.168.1.36:19000,http://localhost:19000,http://localhost:19001,http://localhost:19002,*"
    CORS_ORIGINS: str = "*"
    
    # Dexcom
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
    
    # HealthKit Bridge
    HEALTHKIT_BRIDGE_URL: str = "http://localhost:3001"
    
    # Expo Mobile App
    EXPO_APP_ID: str = "f16e8675-cf9b-4b3d-a4ba-58b21d990311"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore extra fields from environment

settings = Settings()
