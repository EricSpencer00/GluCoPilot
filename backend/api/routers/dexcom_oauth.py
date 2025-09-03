from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/dexcom/oauth", tags=["Dexcom OAuth"]) 

@router.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def dexcom_oauth_removed(path: str):
    raise HTTPException(status_code=status.HTTP_410_GONE, detail="Dexcom OAuth endpoints removed. Use HealthKit and platform OAuth instead.")
