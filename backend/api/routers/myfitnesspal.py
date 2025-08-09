from fastapi import APIRouter, Depends, HTTPException
from datetime import date
from ..dependencies import get_current_user
from ...services.myfitnesspal import MyFitnessPalService

router = APIRouter(prefix="/myfitnesspal", tags=["MyFitnessPal"])

@router.get("/food-logs")
def get_food_logs(start_date: date, end_date: date, user=Depends(get_current_user)):
    # In production, fetch token from user profile
    access_token = user.myfitnesspal_token
    if not access_token:
        raise HTTPException(status_code=401, detail="MyFitnessPal not connected")
    service = MyFitnessPalService(access_token)
    return service.fetch_food_logs(str(start_date), str(end_date))
