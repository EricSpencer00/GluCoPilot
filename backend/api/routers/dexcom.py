from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/dexcom", tags=["Dexcom"])

@router.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def dexcom_removed(path: str):
    """Dexcom endpoints have been removed. Use HealthKit-backed endpoints instead."""
    raise HTTPException(status_code=status.HTTP_410_GONE, detail="Dexcom integration removed. Use HealthKit as the data source.")
