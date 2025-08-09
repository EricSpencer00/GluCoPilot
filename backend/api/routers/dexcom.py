from backend.services.auth import get_current_active_user
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from core.database import get_db
from core.models import User
from services.dexcom import DexcomService
from schemas.dexcom import DexcomLoginRequest, DexcomLoginResponse

router = APIRouter()

@router.post("/login", response_model=DexcomLoginResponse)
def dexcom_login(
    login_request: DexcomLoginRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Login to Dexcom and fetch initial data."""
    try:
        dexcom_service = DexcomService()
        dexcom_service.authenticate(
            username=login_request.username, password=login_request.password
        )
        # Optionally fetch initial data here
        return {"message": "Dexcom login successful"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
