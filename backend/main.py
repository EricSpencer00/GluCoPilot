from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import base64
import json
import os
from dotenv import load_dotenv

from api.routers import auth, glucose, prediction
from api.routers.recommendations import router as recommendations
from api.routers.food import router as food
from api.routers.insulin import router as insulin
from api.routers.integrations import router as integrations
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
    logger.debug("Starting GluCoPilot Backend...")
    
    # Initialize database only if enabled
    if settings.USE_DATABASE:
        await create_tables()
        logger.debug("Database initialized")
    else:
        logger.debug("Stateless mode: skipping database initialization")
    
    # Start background tasks (to be implemented)
    # await start_background_tasks()
    logger.debug("Background tasks will be implemented later")
    
    yield
    
    # Cleanup
    logger.debug("Shutting down GluCoPilot Backend...")
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
app.include_router(detailed_insights, prefix="/api/v1/insights", tags=["AI Insights"])
# Dexcom integration has been removed in favor of HealthKit data sources.
# Previously included Dexcom routers have been disabled to avoid exposing Dexcom-specific endpoints.
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
            # Try to safely decode the JWT header (first part) to log alg/kid preview.
            # We decode only the JWT header (no payload or signature) and log minimal metadata.
            try:
                if len(parts) > 1 and '.' in parts[1]:
                    token = parts[1]
                    header_b64 = token.split('.', 1)[0]
                    # Add padding if necessary for base64 decoding
                    padding = '=' * (-len(header_b64) % 4)
                    header_json = base64.urlsafe_b64decode(header_b64 + padding).decode('utf-8')
                    header_obj = json.loads(header_json)
                    alg = header_obj.get('alg')
                    kid = header_obj.get('kid')
                    kid_preview = (kid[:8] + '...') if isinstance(kid, str) and len(kid) > 8 else kid
                    headers['authorization_meta'] = f"alg={alg}, kid={kid_preview}"
            except Exception:
                # Fail silently if token header can't be decoded — do not raise or log raw token
                pass
        except Exception:
            headers['authorization'] = 'Bearer [REDACTED]'
    # Minimal request logging in production to avoid sensitive data in logs
    logger.debug(f"Incoming request: {request.method} {request.url}")
    if getattr(settings, 'DEBUG', False):
        logger.debug(f"Headers: {headers}")
        logger.debug(f"Client: {request.client}")

    response = await call_next(request)

    if getattr(settings, 'DEBUG', False):
        logger.debug(f"Response status: {response.status_code}")
    else:
        logger.debug(f"Response: {request.method} {request.url.path} -> {response.status_code}")
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
