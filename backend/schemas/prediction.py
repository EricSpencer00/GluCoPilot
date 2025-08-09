from typing import List, Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field

class PredictionInput(BaseModel):
    """Input model for prediction requests"""
    time_horizon_minutes: int = Field(30, ge=15, le=240, description="Time horizon for prediction in minutes (15-240)")
    include_activity: bool = Field(True, description="Whether to include activity data in the prediction")
    include_food: bool = Field(True, description="Whether to include food data in the prediction")

class PredictionFactor(BaseModel):
    """Model for a single prediction factor"""
    factor: str
    effect: float
    description: str

class PredictionDetail(BaseModel):
    """Model for prediction details"""
    id: int
    current_value: float
    current_time: datetime
    predicted_value: float
    target_time: datetime
    confidence_interval: List[float]
    is_high_risk: bool
    is_low_risk: bool
    explanation: str

class PredictionMetadata(BaseModel):
    """Model for prediction metadata"""
    model_type: str
    data_points_used: int
    created_at: datetime

class PredictionResponse(BaseModel):
    """Response model for prediction requests"""
    success: bool
    prediction: Optional[PredictionDetail] = None
    contributing_factors: Optional[List[PredictionFactor]] = None
    metadata: Optional[PredictionMetadata] = None
    error: Optional[str] = None

class PredictionAccuracy(BaseModel):
    """Model for prediction accuracy metrics"""
    count: int
    mean_absolute_error: Optional[float] = None
    accuracy_30: Optional[float] = None
    high_risk_precision: Optional[float] = None
    low_risk_precision: Optional[float] = None
