from fastapi import APIRouter, HTTPException, Depends, status, Body
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from ai.insights_engine import AIInsightsEngine
from schemas.recommendations import RecommendationOut
from core.config import settings
from schemas.dexcom import DexcomCredentials
from services.dexcom import DexcomService
from datetime import datetime

router = APIRouter()



@router.get("/recommendations", tags=["Recommendations"])
async def get_recommendations(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Return 5 recent AI-generated recommendations and available endpoints for the authenticated user."""
    # If database usage is disabled, return 410 Gone with instructions to use client-side recommendations or enable DB
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="Database disabled in stateless mode. Enable a database or fetch recommendations client-side.")

    ai_engine = AIInsightsEngine()
    # Gather user data (last 24h glucose, last 50 insulin, last 50 food)
    glucose_data = db.query(GlucoseReading).filter(GlucoseReading.user_id == current_user.id).order_by(GlucoseReading.timestamp.desc()).limit(288).all()
    insulin_data = db.query(Insulin).filter(Insulin.user_id == current_user.id).order_by(Insulin.timestamp.desc()).limit(50).all()
    food_data = db.query(Food).filter(Food.user_id == current_user.id).order_by(Food.timestamp.desc()).limit(50).all()

    # Generate 5 AI recommendations (do not persist)
    recommendations = await ai_engine.generate_recommendations(
        user=current_user,
        glucose_data=glucose_data,
        insulin_data=insulin_data,
        food_data=food_data,
        db=db
    )
    # Only return the 5 most recent, structured recommendations
    recs = []
    for rec in recommendations[:5]:
        recs.append({
            "title": rec.get("title", ""),
            "description": rec.get("description", ""),
            "category": rec.get("category", "general"),
            "priority": rec.get("priority", "medium"),
            "confidence": rec.get("confidence", 0.8),
            "action": rec.get("action", ""),
            "timing": rec.get("timing", ""),
            "context": rec.get("context", {}),
        })

    # List of available endpoints for further actions
    endpoints = [
        {"name": "Get Glucose Data", "path": "/api/v1/glucose/"},
        {"name": "Get Insulin Data", "path": "/api/v1/insulin/"},
        {"name": "Get Food Data", "path": "/api/v1/food/"},
        {"name": "Get Trends", "path": "/api/v1/dexcom/trends"},
        {"name": "Get AI Recommendations", "path": "/api/v1/recommendations/recommendations"},
    ]

    return {"recommendations": recs, "endpoints": endpoints}


@router.post("/stateless", tags=["Recommendations"])
async def get_recommendations_stateless(
    creds: DexcomCredentials = Body(...),
    current_user: User = Depends(get_current_active_user),
):
    """Generate AI recommendations without using the database.
    Fetch recent Dexcom readings using provided credentials, then run the AI engine.
    """
    try:
        # Fetch recent glucose readings (no DB writes)
        dex_service = DexcomService()
        readings = await dex_service.sync_glucose_data_stateless(
            username=creds.username,
            password=creds.password,
            ous=creds.ous or False,
            hours=24,
        )

        # Convert to minimal objects with attributes expected by the engine
        class _Reading:
            def __init__(self, value, timestamp):
                self.value = value
                # Parse ISO timestamp to datetime when possible
                try:
                    self.timestamp = datetime.fromisoformat(timestamp.replace('Z', '+00:00')) if isinstance(timestamp, str) else timestamp
                except Exception:
                    self.timestamp = datetime.utcnow()

        glucose_objs = [_Reading(r.get("value"), r.get("timestamp")) for r in readings]

        ai_engine = AIInsightsEngine()
        recommendations = await ai_engine.generate_recommendations(
            user=current_user,
            glucose_data=glucose_objs,
            insulin_data=[],
            food_data=[],
            db=None,
        )

        recs = []
        for rec in recommendations[:5]:
            recs.append({
                "title": rec.get("title", ""),
                "description": rec.get("description", ""),
                "category": rec.get("category", "general"),
                "priority": rec.get("priority", "medium"),
                "confidence": rec.get("confidence", 0.8),
                "action": rec.get("action", ""),
                "timing": rec.get("timing", ""),
                "context": rec.get("context", {}),
            })

        return {"recommendations": recs}
    except HTTPException:
        raise
    except Exception as e:
        # Hide sensitive errors
        raise HTTPException(status_code=500, detail="Failed to generate recommendations")
