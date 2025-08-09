
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from ai.insights_engine import AIInsightsEngine
from schemas.recommendations import RecommendationOut

router = APIRouter()



@router.get("/recommendations", tags=["Recommendations"])
async def get_recommendations(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Return 5 recent AI-generated recommendations and available endpoints for the authenticated user."""
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
