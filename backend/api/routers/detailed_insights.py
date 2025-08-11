from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from ai.insights_engine import AIInsightsEngine
from typing import Dict, Any

router = APIRouter()

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
