from fastapi import APIRouter, Depends, HTTPException, status, Query, Header
from services.auth_apple import get_current_identity
from services.dexcom_oauth import DexcomOAuth
from core.config import settings

router = APIRouter(prefix="/dexcom/oauth", tags=["Dexcom OAuth"]) 

@router.get("/authorize")
async def authorize(scope: str = Query(default="offline_access"), identity: dict = Depends(get_current_identity)):
    """Return Dexcom OAuth authorization URL to redirect the user."""
    if not settings.DEXCOM_CLIENT_ID or not settings.DEXCOM_REDIRECT_URI:
        raise HTTPException(status_code=400, detail="Dexcom OAuth not configured")
    return {"authorization_url": DexcomOAuth.authorization_url(scope=scope)}

@router.post("/callback")
async def callback(code: str, identity: dict = Depends(get_current_identity)):
    """Handle Dexcom OAuth callback (authorization code -> tokens). Stateless: return tokens to client to store."""
    tokens = await DexcomOAuth.exchange_code_for_tokens(code)
    return tokens

@router.post("/refresh")
async def refresh(refresh_token: str, identity: dict = Depends(get_current_identity)):
    """Refresh Dexcom access token using refresh token."""
    tokens = await DexcomOAuth.refresh_access_token(refresh_token)
    return tokens

@router.get("/egvs")
async def get_egvs(
    start: str = Query(..., description="ISO8601 UTC start timestamp"),
    end: str = Query(..., description="ISO8601 UTC end timestamp"),
    access_token: str | None = Header(default=None, alias="Dexcom-Access-Token"),
    identity: dict = Depends(get_current_identity),
):
    """Fetch EGVs between start and end using a Dexcom OAuth access token passed in header Dexcom-Access-Token."""
    if not access_token:
        raise HTTPException(status_code=400, detail="Missing Dexcom-Access-Token header")
    return await DexcomOAuth.get_glucose_readings(access_token, start, end)
