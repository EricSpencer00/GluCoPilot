from fastapi import APIRouter, HTTPException, Depends, status
from services.auth_apple import get_current_identity
from schemas.dexcom import DexcomCredentials
from pydexcom import Dexcom

router = APIRouter(prefix="/dexcom", tags=["Dexcom"])

@router.post("/signin")
async def dexcom_signin(
    body: DexcomCredentials,
    identity: dict = Depends(get_current_identity),
):
    """Validate Dexcom credentials after Apple Sign In.
    - Requires valid Apple id_token in Authorization header
    - Does NOT persist any credentials (stateless)
    - Returns success if Dexcom login works
    """
    try:
        client = Dexcom(username=body.username, password=body.password, ous=body.ous or False)
        # Make a lightweight call to verify the session
        _ = client.get_current_glucose_reading()
        return {"success": True, "message": "Dexcom sign-in validated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Dexcom sign-in failed: {str(e)}")
