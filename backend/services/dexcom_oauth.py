import httpx
from fastapi import HTTPException, status
from typing import Optional, Dict
from core.config import settings
from utils.logging import get_logger

logger = get_logger(__name__)

TOKEN_URL = "https://sandbox-api.dexcom.com/v2/oauth2/token"
AUTH_URL = "https://sandbox-api.dexcom.com/v2/oauth2/login"
API_BASE = settings.DEXCOM_API_BASE

if settings.DEXCOM_ENV == "production":
    TOKEN_URL = "https://api.dexcom.com/v2/oauth2/token"
    AUTH_URL = "https://api.dexcom.com/v2/oauth2/login"

class DexcomOAuth:
    @staticmethod
    def authorization_url(scope: str = "offline_access") -> str:
        """Generate Dexcom authorization URL for user consent."""
        params = {
            "client_id": settings.DEXCOM_CLIENT_ID,
            "redirect_uri": settings.DEXCOM_REDIRECT_URI,
            "response_type": "code",
            "scope": scope,
        }
        import urllib.parse as up
        return f"{AUTH_URL}?{up.urlencode(params)}"

    @staticmethod
    async def exchange_code_for_tokens(code: str) -> Dict:
        """Exchange authorization code for access and refresh tokens."""
        async with httpx.AsyncClient(timeout=10) as client:
            data = {
                "client_id": settings.DEXCOM_CLIENT_ID,
                "client_secret": settings.DEXCOM_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": settings.DEXCOM_REDIRECT_URI,
            }
            r = await client.post(TOKEN_URL, data=data)
            if r.status_code != 200:
                logger.error(f"Dexcom token exchange failed: {r.text}")
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Dexcom token exchange failed")
            return r.json()

    @staticmethod
    async def refresh_access_token(refresh_token: str) -> Dict:
        async with httpx.AsyncClient(timeout=10) as client:
            data = {
                "client_id": settings.DEXCOM_CLIENT_ID,
                "client_secret": settings.DEXCOM_CLIENT_SECRET,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            }
            r = await client.post(TOKEN_URL, data=data)
            if r.status_code != 200:
                logger.error(f"Dexcom token refresh failed: {r.text}")
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Dexcom token refresh failed")
            return r.json()

    @staticmethod
    async def get_glucose_readings(access_token: str, start: str, end: str) -> Dict:
        """Fetch EGVs between ISO8601 timestamps (Dexcom requires UTC ISO)."""
        headers = {"Authorization": f"Bearer {access_token}"}
        params = {"startDate": start, "endDate": end}
        url = f"{API_BASE}/v3/users/self/egvs"
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=headers, params=params)
            if r.status_code != 200:
                logger.error(f"Dexcom egvs fetch failed: {r.text}")
                raise HTTPException(status_code=r.status_code, detail="Failed to fetch glucose readings")
            return r.json()
