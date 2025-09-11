from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
import os
from core.config import settings
from utils.logging import get_logger

logger = get_logger(__name__)

# Create SQLAlchemy engine
if "sqlite" in settings.DATABASE_URL:
    engine = create_engine(
        settings.DATABASE_URL,
        connect_args={
            "check_same_thread": False,
            "timeout": 30
        },
        poolclass=StaticPool,
        echo=settings.DATABASE_ECHO
    )
else:
    engine = create_engine(
        settings.DATABASE_URL,
        echo=settings.DATABASE_ECHO
    )

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class for models
Base = declarative_base()
metadata = MetaData()

async def create_tables():
    """Create database tables"""
    try:
        from models import user, glucose, insulin, food, analysis, recommendations, health_data
        logger.debug("Creating database tables...")
        Base.metadata.create_all(bind=engine)
        logger.debug("Database tables created successfully")
    except Exception as e:
        logger.error(f"Error creating database tables: {e}")
        raise

from typing import Generator

def get_db() -> Generator[Session, None, None]:
    """Dependency to get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_db_session() -> Session:
    """Get a database session (for background tasks)"""
    return SessionLocal()
