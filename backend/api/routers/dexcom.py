from fastapi import APIRouter, HTTPException, Depends, status
from services.auth import get_current_user
from schemas.dexcom import DexcomCredentials, DexcomLoginResponse
from pydexcom import Dexcom

router = APIRouter(prefix="/dexcom", tags=["Dexcom"])  

@router.post("/login", response_model=DexcomLoginResponse)
async def dexcom_login(
    body: DexcomCredentials,
    _user=Depends(get_current_user),
):
    """Validate Dexcom credentials (stateless). Does not persist anything."""
    try:
        client = Dexcom(username=body.username, password=body.password, ous=body.ous or False)
        # Lightweight call to ensure credentials/session are valid
        _ = client.get_current_glucose_reading()
        return {"message": "Dexcom login successful"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Dexcom login failed: {str(e)}")
