from fastapi import APIRouter, Depends, HTTPException
from datetime import date
from ..dependencies import get_current_user
from ...services.dexcom_trends import get_long_term_trends
from ...services.dexcom import get_dexcom_for_user

router = APIRouter(prefix="/trends", tags=["Trends"])

@router.get("/dexcom")
def get_dexcom_trends(days: int = 30, user=Depends(get_current_user)):
    dexcom = get_dexcom_for_user(user)
    if not dexcom:
        raise HTTPException(status_code=401, detail="Dexcom not connected")
    return get_long_term_trends(dexcom, days=days)
