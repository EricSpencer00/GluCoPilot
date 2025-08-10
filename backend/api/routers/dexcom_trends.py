
from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import date, datetime
from api.dependencies import get_current_user
from services.dexcom_trends import get_long_term_trends
from services.dexcom import get_dexcom_for_user

router = APIRouter(prefix="/trends", tags=["Trends"])

@router.get("/dexcom")
def get_dexcom_trends(
    days: int = 30,
    startDate: str = Query(None, description="Start date in YYYY-MM-DD format"),
    endDate: str = Query(None, description="End date in YYYY-MM-DD format"),
    user=Depends(get_current_user)
):
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
