from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, Body
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
from datetime import datetime, timedelta
from typing import List, Optional

from core.database import get_db
from core.config import settings
from models.user import User
from models.glucose import GlucoseReading
from schemas.glucose import GlucoseReadingCreate, GlucoseReadingResponse, GlucoseStats
from services.auth import get_current_active_user
from schemas.dexcom import DexcomCredentials
# Dexcom integration removed; services.dexcom contains a removal stub. Avoid importing DexcomService.
from utils.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()

# Simple in-memory rate limiter for stateless Dexcom calls
_stateless_rate_limit = {}
# Allow one stateless call per username per 30 seconds
STATELESS_RATE_SECONDS = 30


@router.get("/readings", response_model=List[GlucoseReadingResponse])
async def get_glucose_readings(
    start_date: Optional[datetime] = Query(None, description="Start date for readings"),
    end_date: Optional[datetime] = Query(None, description="End date for readings"),
    limit: int = Query(100, le=1000, description="Maximum number of readings to return"),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get glucose readings for the current user"""
    # Block DB-backed endpoint in stateless mode
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Disabled in stateless mode. Use POST /api/v1/glucose/stateless/sync with Dexcom credentials.")

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
    # Block DB-backed endpoint in stateless mode
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Disabled in stateless mode. Use POST /api/v1/glucose/stateless/latest with Dexcom credentials.")

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
    # Block DB-backed endpoint in stateless mode
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Disabled in stateless mode.")

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
    # Block DB-backed endpoint in stateless mode
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Disabled in stateless mode. Use POST /api/v1/glucose/stateless/stats with Dexcom credentials.")

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
    creds: DexcomCredentials | None = Body(None),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync glucose data from Dexcom CGM.

    In DB mode this uses stored credentials on the user record. In stateless mode,
    the client must provide Dexcom credentials in the request body (DexcomCredentials) or
    call the stateless endpoints directly. This avoids accessing non-existent attributes on SimpleUser.
    """
    # Dexcom integration has been removed from the backend. Provide a clear 410 response
    # so clients can migrate to HealthKit-based uploads or client-side sync flows.
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Dexcom integration removed. Use HealthKit on the client to collect glucose data and send it to the backend via /api/v1/health/sync or the appropriate stateless endpoints."
    )

@router.post('/stateless/sync')
async def stateless_sync_dexcom(
    creds: DexcomCredentials = Body(...),
    hours: int = Query(24, ge=1, le=72),
    request: Request = None
):
    """Fetch Dexcom readings using provided credentials without any DB writes.
    Rate-limited and intended for stateless usage where credentials are provided each call.
    Returns a JSON object with `readings` list.
    """
    username = creds.username

    # Rate limiting per username
    now = datetime.utcnow().timestamp()
    last = _stateless_rate_limit.get(username)
    if last and (now - last) < STATELESS_RATE_SECONDS:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=f"Rate limit exceeded. Try again in {int(STATELESS_RATE_SECONDS - (now - last))}s")
    _stateless_rate_limit[username] = now

    # Dexcom removed — return 410 with guidance
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Dexcom integration removed. Please use HealthKit on the client device and the backend health sync endpoints."
    )


@router.post('/stateless/latest')
async def stateless_get_latest(
    creds: DexcomCredentials = Body(...),
):
    """Return the most recent Dexcom reading using provided credentials (no DB writes)."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Dexcom integration removed. Use HealthKit on the client and upload readings via /api/v1/health/sync or a client-side sync."
    )

@router.post('/stateless/stats', response_model=GlucoseStats)
async def stateless_get_stats(
    creds: DexcomCredentials = Body(...),
    hours: int = Query(24, ge=1, le=72)
):
    """Compute glucose statistics from Dexcom readings using provided credentials (no DB writes).
    Note: Dexcom Share via pydexcom limits history to ~24h (up to 72h depending on server)."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Dexcom integration removed. Use client-collected HealthKit data and call /api/v1/health/sync or the insights endpoints instead."
    )
