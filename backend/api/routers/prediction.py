from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from core.database import get_db
from services.prediction import PredictionService
from models.user import User
from schemas.prediction import (
    PredictionInput, 
    PredictionResponse,
    PredictionAccuracy
)
from api.routers.auth import get_current_user

router = APIRouter(prefix="/predict", tags=["Prediction"])
prediction_service = PredictionService()

@router.post("/", response_model=PredictionResponse)
async def generate_prediction(
    input_data: PredictionInput,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Generate glucose predictions based on the user's data
    
    This endpoint analyzes recent glucose readings, insulin doses, food intake,
    and activity data to predict future glucose levels. It uses a combination
    of clinical models and machine learning to generate predictions.
    
    The prediction includes:
    - Future glucose value
    - Confidence interval
    - Contributing factors with explanations
    - Risk assessment for potential highs or lows
    """
    try:
        result = await prediction_service.generate_predictions(
            user=current_user,
            db=db,
            time_horizon_minutes=input_data.time_horizon_minutes,
            include_activity=input_data.include_activity,
            include_food=input_data.include_food
        )
        
        return result
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate prediction: {str(e)}"
        )

@router.get("/accuracy", response_model=PredictionAccuracy)
async def get_prediction_accuracy(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get accuracy metrics for the user's glucose predictions
    
    This endpoint returns various accuracy metrics for past predictions:
    - Mean absolute error
    - Percentage of predictions within 30 mg/dL
    - Precision of high and low risk predictions
    """
    try:
        # First validate any unvalidated predictions
        await prediction_service.validate_predictions(current_user, db)
        
        # Then get overall accuracy stats
        accuracy = await prediction_service.get_user_prediction_accuracy(current_user, db)
        
        return accuracy
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve prediction accuracy: {str(e)}"
        )

@router.get("/", response_model=PredictionResponse)
async def get_quick_prediction(
    time_horizon_minutes: int = Query(30, ge=15, le=240),
    include_activity: bool = Query(True),
    include_food: bool = Query(True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a quick glucose prediction using default parameters
    
    This is a convenience endpoint that accepts query parameters
    instead of requiring a JSON request body.
    """
    try:
        result = await prediction_service.generate_predictions(
            user=current_user,
            db=db,
            time_horizon_minutes=time_horizon_minutes,
            include_activity=include_activity,
            include_food=include_food
        )
        
        return result
    
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate prediction: {str(e)}"
        )

@router.get("/myfitnesspal-status")
async def get_myfitnesspal_status(
    current_user: User = Depends(get_current_user)
):
    """
    Get the status of MyFitnessPal integration for the current user
    
    This is a placeholder endpoint for MyFitnessPal integration.
    In a future implementation, this would check if the user has
    connected their MyFitnessPal account and return the status.
    """
    # Placeholder for MyFitnessPal integration
    return {
        "connected": False,
        "message": "MyFitnessPal integration is not yet implemented."
    }

@router.get("/activity-status")
async def get_activity_status(
    current_user: User = Depends(get_current_user)
):
    """
    Get the status of activity data integration for the current user
    
    This is a placeholder endpoint for Apple Health / activity data integration.
    In a future implementation, this would check if the user has
    connected their Apple Health or other activity tracker and return the status.
    """
    # Placeholder for activity data integration
    return {
        "connected": False,
        "sources": [],
        "message": "Activity data integration is not yet implemented."
    }
