from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
from datetime import datetime, timedelta
from typing import List, Optional

from core.database import get_db
from models.user import User
from models.glucose import GlucoseReading
from schemas.glucose import GlucoseReadingCreate, GlucoseReadingResponse, GlucoseStats
from services.auth import get_current_active_user
from services.dexcom import DexcomService
from utils.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()

@router.get("/readings", response_model=List[GlucoseReadingResponse])
async def get_glucose_readings(
    start_date: Optional[datetime] = Query(None, description="Start date for readings"),
    end_date: Optional[datetime] = Query(None, description="End date for readings"),
    limit: int = Query(100, le=1000, description="Maximum number of readings to return"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get glucose readings for the current user"""
    logger.info(f"Fetching glucose readings for user {current_user.id}")
    
    query = db.query(GlucoseReading).filter(GlucoseReading.user_id == current_user.id)
    
    # Apply date filters
    if start_date:
        query = query.filter(GlucoseReading.timestamp >= start_date)
    if end_date:
        query = query.filter(GlucoseReading.timestamp <= end_date)
    
    # Order by timestamp descending and limit
    readings = query.order_by(desc(GlucoseReading.timestamp)).limit(limit).all()
    
    # Attach trend_arrow to each reading
    def map_trend_arrow(trend):
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
        return mapping.get(trend, None)
    
    for r in readings:
        r.trend_arrow = map_trend_arrow(r.trend)
    
    logger.info(f"Retrieved {len(readings)} glucose readings")
    return readings

@router.get("/latest", response_model=GlucoseReadingResponse)
async def get_latest_glucose(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get the most recent glucose reading"""
    reading = db.query(GlucoseReading)\
        .filter(GlucoseReading.user_id == current_user.id)\
        .order_by(desc(GlucoseReading.timestamp))\
        .first()
    
    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No glucose readings found"
        )
    # Attach trend_arrow
    def map_trend_arrow(trend):
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
        return mapping.get(trend, None)
    reading.trend_arrow = map_trend_arrow(reading.trend)
    
    return reading

@router.post("/readings", response_model=GlucoseReadingResponse)
async def create_glucose_reading(
    reading_data: GlucoseReadingCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Create a manual glucose reading"""
    logger.info(f"Creating manual glucose reading for user {current_user.id}")
    
    reading = GlucoseReading(
        user_id=current_user.id,
        value=reading_data.value,
        timestamp=reading_data.timestamp or datetime.utcnow(),
        source="manual",
        quality="user_entered"
    )
    
    # Determine alerts based on value
    if reading.value < 54:
        reading.is_urgent_low = True
        reading.is_low_alert = True
    elif reading.value < 70:
        reading.is_low_alert = True
    elif reading.value > 250:
        reading.is_high_alert = True
    
    db.add(reading)
    db.commit()
    db.refresh(reading)
    
    logger.info(f"Created glucose reading: {reading.value} mg/dL")
    return reading

@router.get("/stats", response_model=GlucoseStats)
async def get_glucose_stats(
    days: int = Query(7, ge=1, le=90, description="Number of days to analyze"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get glucose statistics for the specified period"""
    logger.info(f"Calculating glucose stats for user {current_user.id}, {days} days")
    
    start_date = datetime.utcnow() - timedelta(days=days)
    
    readings = db.query(GlucoseReading)\
        .filter(
            and_(
                GlucoseReading.user_id == current_user.id,
                GlucoseReading.timestamp >= start_date
            )
        )\
        .all()
    
    if not readings:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No glucose data found for the specified period"
        )
    
    # Calculate statistics
    values = [r.value for r in readings]
    total_readings = len(values)
    
    # Time in range calculations
    in_range_count = len([v for v in values if 70 <= v <= 180])
    low_count = len([v for v in values if v < 70])
    high_count = len([v for v in values if v > 180])
    
    stats = GlucoseStats(
        total_readings=total_readings,
        average_glucose=round(sum(values) / total_readings, 1),
        time_in_range=round((in_range_count / total_readings) * 100, 1),
        time_below_range=round((low_count / total_readings) * 100, 1),
        time_above_range=round((high_count / total_readings) * 100, 1),
        glucose_management_indicator=round(3.31 + (0.02392 * (sum(values) / total_readings)), 1),
        coefficient_of_variation=round((
            (sum([(v - (sum(values) / total_readings)) ** 2 for v in values]) / total_readings) ** 0.5
            / (sum(values) / total_readings)
        ) * 100, 1),
        period_days=days
    )
    
    logger.info(f"Glucose stats calculated: TIR={stats.time_in_range}%")
    return stats

@router.post("/sync")
async def sync_dexcom_data(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync glucose data from Dexcom CGM"""
    logger.info(f"Starting Dexcom sync for user {current_user.id}")
    
    if not current_user.dexcom_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Dexcom credentials not configured"
        )
    
    try:
        dexcom_service = DexcomService()
        new_readings = await dexcom_service.sync_glucose_data(current_user, db)
        
        logger.info(f"Dexcom sync completed: {len(new_readings)} new readings")
        return {
            "message": f"Successfully synced {len(new_readings)} new readings",
            "new_readings": len(new_readings)
        }
    
    except Exception as e:
        logger.error(f"Dexcom sync failed for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync Dexcom data: {str(e)}"
        )
