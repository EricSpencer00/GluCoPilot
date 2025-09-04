from fastapi import APIRouter, HTTPException, Depends, Body, Request
from sqlalchemy.orm import Session
from services.auth import get_current_active_user, get_optional_current_user, SimpleUser
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
    current_user: User = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
    request: Request = None,
):
    """Generate AI insights and recommendations for the user."""
    ai_engine = AIInsightsEngine()
    
    try:
        # If database usage is disabled, accept stateless mode where caller provides health_data + api_key
        if not settings.USE_DATABASE:
            # Allow either: (A) a valid bearer token (current_user present), or (B) an API key supplied
            # If a bearer token is present, trust it and proceed without API key.
            if current_user is None:
                # No bearer token - require API key in body or header
                api_key = None
                if isinstance(request_data, dict):
                    api_key = request_data.get('api_key')
                if not api_key and request is not None:
                    api_key = request.headers.get('x-api-key') or request.headers.get('x_api_key')
                # Allow alternate stateless API key via env var
                import os
                stateless_key = os.getenv('STATELESS_API_KEY')

                # In non-production environments, allow missing or any API key (useful for testing)
                if settings.ENVIRONMENT.lower() != 'production':
                    if not api_key:
                        # Log warning but continue
                        from utils.logging import get_logger
                        get_logger(__name__).warning("Stateless insights called without api_key in non-production environment; accepting for testing")
                    # else: accept any provided key
                else:
                    # Production: require a matching key
                    if not api_key or (api_key != settings.SECRET_KEY and (not stateless_key or api_key != stateless_key)):
                        raise HTTPException(status_code=401, detail="Invalid or missing API key for stateless insights")

            # Expect health_data in the request body
            health_data = (request_data or {}).get('health_data') if isinstance(request_data, dict) else None
            if not health_data or not isinstance(health_data, dict):
                raise HTTPException(status_code=400, detail="Missing or invalid 'health_data' in request body")

            # Parse glucose readings from health_data
            glucose_readings = health_data.get('glucose', [])
            # Minimal reading object expected by the AI engine
            from datetime import datetime, timezone
            class _Reading:
                def __init__(self, value, timestamp):
                    self.value = value
                    try:
                        if isinstance(timestamp, str):
                            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        elif isinstance(timestamp, datetime):
                            dt = timestamp
                        else:
                            dt = datetime.utcnow()
                        if getattr(dt, 'tzinfo', None) is not None:
                            dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
                        self.timestamp = dt
                    except Exception:
                        self.timestamp = datetime.utcnow()

            glucose_objs = []
            for r in glucose_readings:
                try:
                    glucose_objs.append(_Reading(r.get('value'), r.get('timestamp')))
                except Exception:
                    continue

            # Parse optional food and activity datasets
            food_items = health_data.get('food', [])
            activity_items = health_data.get('activity', [])

            # Create minimal objects for food/activity/insulin; the engine mainly uses timestamps and simple values
            class _Food:
                def __init__(self, name: str, calories: float | int | None, carbs: float | int | None, timestamp):
                    self.name = name
                    self.calories = calories or 0
                    # support both 'carbs' and 'total_carbs' keys
                    self.total_carbs = carbs or 0
                    try:
                        if isinstance(timestamp, str):
                            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        elif isinstance(timestamp, datetime):
                            dt = timestamp
                        else:
                            dt = datetime.utcnow()
                        if getattr(dt, 'tzinfo', None) is not None:
                            from datetime import timezone as _tz
                            dt = dt.astimezone(_tz.utc).replace(tzinfo=None)
                        self.timestamp = dt
                    except Exception:
                        self.timestamp = datetime.utcnow()

            class _Activity:
                def __init__(self, type: str, duration: float | int | None, calories: float | int | None, start, end=None):
                    self.type = type
                    self.duration = float(duration or 0)
                    self.calories = float(calories or 0)
                    # Prefer 'start'/'end' fields if present; fallback to timestamp
                    def _parse(d):
                        if d is None:
                            return None
                        if isinstance(d, str):
                            try:
                                return datetime.fromisoformat(d.replace('Z', '+00:00'))
                            except Exception:
                                return None
                        if isinstance(d, datetime):
                            return d
                        return None
                    self.start_time = _parse(start) or datetime.utcnow()
                    self.end_time = _parse(end) or self.start_time
                    # For compatibility with any code expecting `.timestamp`
                    self.timestamp = self.start_time

            food_objs = []
            for f in food_items:
                try:
                    food_objs.append(
                        _Food(
                            f.get('name') or f.get('title') or 'Food',
                            f.get('calories'),
                            f.get('carbs') or f.get('total_carbs'),
                            f.get('timestamp')
                        )
                    )
                except Exception:
                    continue

            activity_objs = []
            for a in activity_items:
                try:
                    activity_objs.append(
                        _Activity(
                            a.get('type') or a.get('name') or 'activity',
                            a.get('duration'),
                            a.get('calories'),
                            a.get('start') or a.get('startDate') or a.get('timestamp'),
                            a.get('end') or a.get('endDate')
                        )
                    )
                except Exception:
                    continue

            insulin_objs = []

            # Create or reuse a lightweight stateless user object
            if current_user is None:
                stateless_user = SimpleUser(username=(request_data.get('username', 'stateless') if isinstance(request_data, dict) else 'stateless'))
            else:
                # Use the authenticated user (SimpleUser or full User)
                stateless_user = current_user

            # Call AI engine without DB
            recommendations = await ai_engine.generate_recommendations(
                user=stateless_user,
                glucose_data=glucose_objs,
                insulin_data=insulin_objs,
                food_data=food_objs,
                db=None,
                activity_data=activity_objs,
            )
        else:
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

            # Generate recommendations/insights using DB-backed data
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
                "description": rec.get("description", ""),
                # Map to frontend's expected enums; also include a type alias
                "category": rec.get("category", "general"),
                "type": rec.get("category", "pattern"),
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
        
    except HTTPException:
        # let explicit HTTPExceptions (like 503) pass through
        raise
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
