from pydantic import BaseModel, Field, validator
from datetime import datetime
from typing import Optional

class GlucoseReadingBase(BaseModel):
    """Base glucose reading schema"""
    value: float = Field(..., ge=20, le=600, description="Glucose value in mg/dL")
    trend: Optional[str] = Field(None, description="Glucose trend direction")
    timestamp: Optional[datetime] = None

class GlucoseReadingCreate(GlucoseReadingBase):
    """Create glucose reading schema"""
    
    @validator('value')
    def validate_glucose_value(cls, v):
        if not (20 <= v <= 600):
            raise ValueError('Glucose value must be between 20 and 600 mg/dL')
        return v

class GlucoseReadingResponse(GlucoseReadingBase):
    """Glucose reading response schema"""
    id: int
    user_id: int
    trend_rate: Optional[float]
    source: str
    quality: Optional[str]
    is_high_alert: bool
    is_low_alert: bool
    is_urgent_low: bool
    created_at: datetime
    glucose_status: str
    is_in_range: bool
    trend_arrow: Optional[str] = Field(None, description="Glucose trend arrow (e.g., ↑, ↓, →)")

    @property
    def trend_arrow(self) -> Optional[str]:
        mapping = {
            "rising_rapidly": "↑↑",
            "rising": "↑",
            "rising_slightly": "↗",
            "stable": "→",
            "falling_slightly": "↘",
            "falling": "↓",
            "falling_rapidly": "↓↓",
            "unknown": "?",
            "not_computable": "NC"
        }
        return mapping.get(self.trend, None)

    class Config:
        from_attributes = True

class GlucoseStats(BaseModel):
    """Glucose statistics schema"""
    total_readings: int
    average_glucose: float = Field(..., description="Average glucose in mg/dL")
    time_in_range: float = Field(..., description="Percentage time in range (70-180 mg/dL)")
    time_below_range: float = Field(..., description="Percentage time below 70 mg/dL")
    time_above_range: float = Field(..., description="Percentage time above 180 mg/dL")
    glucose_management_indicator: float = Field(..., description="Estimated HbA1c equivalent")
    coefficient_of_variation: float = Field(..., description="Glucose variability percentage")
    period_days: int = Field(..., description="Number of days analyzed")

class GlucoseTrend(BaseModel):
    """Glucose trend data schema"""
    timestamp: datetime
    value: float
    trend: str
    rate: Optional[float] = Field(None, description="Rate of change in mg/dL per minute")

class DailySummary(BaseModel):
    """Daily glucose summary schema"""
    date: datetime
    readings_count: int
    average_glucose: float
    time_in_range: float
    lowest_glucose: float
    highest_glucose: float
    standard_deviation: float
