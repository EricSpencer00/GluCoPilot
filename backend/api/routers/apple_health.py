from fastapi import APIRouter, Depends, HTTPException
from datetime import date
from ..dependencies import get_current_user
from ...services.apple_health import AppleHealthService

router = APIRouter(prefix="/apple-health", tags=["Apple Health"])

@router.get("/activity")
def get_activity(start_date: date, end_date: date, user=Depends(get_current_user)):
    service = AppleHealthService(user.id)
    return service.fetch_activity_data(str(start_date), str(end_date))
