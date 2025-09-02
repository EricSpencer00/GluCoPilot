from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import os
from dotenv import load_dotenv

from api.routers import auth, glucose, prediction
from api.routers.recommendations import router as recommendations
from api.routers.food import router as food
from api.routers.insulin import router as insulin
from api.routers.integrations import router as integrations
from api.routers.dexcom_trends import router as dexcom_trends
from api.routers.detailed_insights import router as detailed_insights
from api.routers.health import router as health
from api.routers import forgot_password
from core.database import get_db, create_tables
from core.config import settings
# Background tasks service will be implemented later
# from services.background_tasks import start_background_tasks, stop_background_tasks
from utils.logging import setup_logging

# Load environment variables
load_dotenv()

# Setup logging
logger = setup_logging()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown events"""
    logger.info("Starting GluCoPilot Backend...")
    
    # Initialize database only if enabled
    if settings.USE_DATABASE:
        await create_tables()
        logger.info("Database initialized")
    else:
        logger.info("Stateless mode: skipping database initialization")
    
    # Start background tasks (to be implemented)
    # await start_background_tasks()
    logger.info("Background tasks will be implemented later")
    
    yield
    
    # Cleanup
    logger.info("Shutting down GluCoPilot Backend...")
    # await stop_background_tasks()

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
app.include_router(auth, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(forgot_password.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(glucose, prefix="/api/v1/glucose", tags=["Glucose"])
app.include_router(recommendations, prefix="/api/v1/recommendations", tags=["Recommendations"])
app.include_router(prediction, prefix="/api/v1/predict", tags=["Prediction"])
app.include_router(food, prefix="/api/v1/food", tags=["Food"])
app.include_router(insulin, prefix="/api/v1/insulin", tags=["Insulin"])
app.include_router(integrations, prefix="/api/v1/integrations", tags=["Integrations"])
app.include_router(health, prefix="/api/v1/health", tags=["Health"])
app.include_router(dexcom_trends, prefix="/api/v1", tags=["Trends"])
app.include_router(detailed_insights, prefix="/api/v1/insights", tags=["AI Insights"])
from api.routers.dexcom_signin import router as dexcom_signin
app.include_router(dexcom_signin, prefix="/api/v1", tags=["Dexcom"])
from api.routers.dexcom_oauth import router as dexcom_oauth
app.include_router(dexcom_oauth, prefix="/api/v1", tags=["Dexcom OAuth"])
# Feedback router
from api.routers import feedback
if feedback:
    app.include_router(feedback, prefix="/api/v1", tags=["Feedback"])

@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Redact Authorization header and avoid logging bodies/sensitive data
    headers = dict(request.headers)
    # Provide a masked preview of the Authorization header for debugging (do NOT log full token)
    auth_header = None
    if 'authorization' in headers:
        auth_header = headers.get('authorization')
        try:
            parts = auth_header.split(' ', 1)
            token_type = parts[0] if len(parts) > 0 else 'unknown'
            token_preview = parts[1][:8] + '...' if len(parts) > 1 else '[no-token]'
            headers['authorization'] = f"{token_type} [REDACTED:{token_preview}]"
        except Exception:
            headers['authorization'] = 'Bearer [REDACTED]'
    logger.info(f"Incoming request: {request.method} {request.url}")
    logger.info(f"Headers: {headers}")
    logger.info(f"Client: {request.client}")

    response = await call_next(request)

    logger.info(f"Response status: {response.status_code}")
    return response

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
    try:
        import uvicorn
        uvicorn.run(
            "main:app",
            host=settings.API_HOST,
            port=settings.API_PORT,
            reload=settings.DEBUG
        )
    except ImportError:
        print("Uvicorn not installed. Please install with 'pip install uvicorn'.")
