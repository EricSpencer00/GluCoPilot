from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import os
from dotenv import load_dotenv

from api.routers import auth, glucose, insulin, food, analysis, recommendations, health
from core.database import get_db, create_tables
from core.config import settings
from services.background_tasks import start_background_tasks, stop_background_tasks
from utils.logging import setup_logging

# Load environment variables
load_dotenv()

# Setup logging
logger = setup_logging()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown events"""
    logger.info("Starting GluCoPilot Backend...")
    
    # Initialize database
    await create_tables()
    logger.info("Database initialized")
    
    # Start background tasks
    await start_background_tasks()
    logger.info("Background tasks started")
    
    yield
    
    # Cleanup
    logger.info("Shutting down GluCoPilot Backend...")
    await stop_background_tasks()

# Create FastAPI app
app = FastAPI(
    title="GluCoPilot API",
    description="AI-Powered Diabetes Management Backend",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Include routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(glucose.router, prefix="/api/v1/glucose", tags=["Glucose"])
app.include_router(insulin.router, prefix="/api/v1/insulin", tags=["Insulin"])
app.include_router(food.router, prefix="/api/v1/food", tags=["Food"])
app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["Analysis"])
app.include_router(recommendations.router, prefix="/api/v1/recommendations", tags=["Recommendations"])
app.include_router(health.router, prefix="/api/v1/health", tags=["Health"])

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to GluCoPilot API",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": "2025-08-08T00:00:00Z"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.DEBUG
    )
