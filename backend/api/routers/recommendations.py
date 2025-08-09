
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


@router.get("/recommendations", tags=["Recommendations"], response_model=dict)
async def get_recommendations(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Return AI-generated recommendations for the authenticated user."""
    ai_engine = AIInsightsEngine()
    # Gather user data
    glucose_data = db.query(GlucoseReading).filter(GlucoseReading.user_id == current_user.id).order_by(GlucoseReading.timestamp.desc()).limit(288).all()
    insulin_data = db.query(Insulin).filter(Insulin.user_id == current_user.id).order_by(Insulin.timestamp.desc()).limit(50).all()
    food_data = db.query(Food).filter(Food.user_id == current_user.id).order_by(Food.timestamp.desc()).limit(50).all()
    # Generate recommendations
    recommendations = await ai_engine.generate_recommendations(
        user=current_user,
        glucose_data=glucose_data,
        insulin_data=insulin_data,
        food_data=food_data,
        db=db
    )
    # Validate with Pydantic schema
    return {"recommendations": [RecommendationOut(**rec) for rec in recommendations]}
