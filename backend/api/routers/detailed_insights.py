from fastapi import APIRouter, HTTPException, Depends, Body
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from ai.insights_engine import AIInsightsEngine
from typing import Dict, Any, Optional
from core.config import settings
from schemas.dexcom import DexcomCredentials
from services.dexcom import DexcomService
from datetime import datetime

router = APIRouter()

@router.post("/generate", tags=["AI Insights"])
async def generate_insights(
    request_data: Optional[Dict[str, Any]] = Body(default={}),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Generate AI insights and recommendations for the user."""
    ai_engine = AIInsightsEngine()
    
    try:
        # If database is disabled, try to use stateless mode
        if not settings.USE_DATABASE:
            # Return error for now, could implement stateless mode later
            raise HTTPException(
                status_code=503,
                detail="Database disabled in stateless mode. Insights generation requires database."
            )
        
        # Gather user data (last 24h glucose, last 50 insulin, last 50 food)
        glucose_data = db.query(GlucoseReading).filter(
            GlucoseReading.user_id == current_user.id
        ).order_by(GlucoseReading.timestamp.desc()).limit(288).all()
        
        insulin_data = db.query(Insulin).filter(
            Insulin.user_id == current_user.id
        ).order_by(Insulin.timestamp.desc()).limit(50).all()
        
        food_data = db.query(Food).filter(
            Food.user_id == current_user.id
        ).order_by(Food.timestamp.desc()).limit(50).all()

        # Generate recommendations/insights
        recommendations = await ai_engine.generate_recommendations(
            user=current_user,
            glucose_data=glucose_data,
            insulin_data=insulin_data,
            food_data=food_data,
            db=db
        )
        
        # Format insights for frontend
        insights = []
        for rec in recommendations[:5]:  # Return top 5 insights
            insights.append({
                "id": rec.get("context", {}).get("recommendation_id", f"insight_{len(insights)}"),
                "title": rec.get("title", ""),
                "content": rec.get("description", ""),
                "category": rec.get("category", "general"),
                "priority": rec.get("priority", "medium"),
                "confidence": rec.get("confidence", 0.8),
                "actionable": bool(rec.get("action", "")),
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "metadata": {
                    "action": rec.get("action", ""),
                    "timing": rec.get("timing", ""),
                    "context": rec.get("context", {})
                }
            })
        
        return {
            "insights": insights,
            "total_count": len(insights),
            "generated_at": datetime.utcnow().isoformat() + "Z"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating insights: {str(e)}"
        )

@router.post("/detailed-insight", tags=["AI Insights"])
async def get_detailed_insight(
    recommendation: Dict[str, Any],
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Generate a detailed drill-down analysis for a specific recommendation."""
    ai_engine = AIInsightsEngine()
    
    try:
        # Generate detailed analysis based on the recommendation
        detailed_analysis = await ai_engine.explain_recommendation_drilldown(
            recommendation=recommendation,
            user=current_user
        )
        
        return {
            "detail": detailed_analysis,
            "original_recommendation": recommendation,
            "timestamp": recommendation.get("context", {}).get("generated_at"),
            "recommendation_id": recommendation.get("context", {}).get("recommendation_id", "")
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating detailed insight: {str(e)}"
        )
