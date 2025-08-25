from fastapi import APIRouter, Depends, HTTPException, Query, Body
from datetime import date, datetime
from api.dependencies import get_current_user
from services.dexcom_trends import get_long_term_trends
from services.dexcom import get_dexcom_for_user
from schemas.dexcom import DexcomTrendsRequest
from core.config import settings
from pydexcom import Dexcom

router = APIRouter(prefix="/trends", tags=["Trends"])

@router.get("/dexcom")
def get_dexcom_trends(
    days: int = 30,
    startDate: str = Query(None, description="Start date in YYYY-MM-DD format"),
    endDate: str = Query(None, description="End date in YYYY-MM-DD format"),
    user=Depends(get_current_user)
):
    # In stateless mode, this GET endpoint is disabled to avoid DB usage.
    if not settings.USE_DATABASE:
        raise HTTPException(status_code=410, detail="Disabled in stateless mode. Use POST /api/v1/trends/dexcom with credentials.")

    dexcom = get_dexcom_for_user(user)
    if not dexcom:
        raise HTTPException(status_code=401, detail="Dexcom not connected")

    # Parse dates if provided
    start_dt = None
    end_dt = None
    try:
        if startDate:
            start_dt = datetime.strptime(startDate, "%Y-%m-%d")
        if endDate:
            end_dt = datetime.strptime(endDate, "%Y-%m-%d")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")

    return get_long_term_trends(dexcom, days=days, start_date=start_dt, end_date=end_dt)

@router.post("/dexcom")
def get_dexcom_trends_stateless(payload: DexcomTrendsRequest = Body(...)):
    """Compute Dexcom long-term trends using credentials provided in the request (stateless)."""
    # Build Dexcom client from credentials
    dexcom = Dexcom(
        username=payload.username,
        password=payload.password,
        ous=payload.ous or False
    )

    # Parse dates if provided
    start_dt = None
    end_dt = None
    try:
        if payload.startDate:
            start_dt = datetime.strptime(payload.startDate, "%Y-%m-%d")
        if payload.endDate:
            end_dt = datetime.strptime(payload.endDate, "%Y-%m-%d")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")

    return get_long_term_trends(dexcom, days=payload.days or 30, start_date=start_dt, end_date=end_dt)
