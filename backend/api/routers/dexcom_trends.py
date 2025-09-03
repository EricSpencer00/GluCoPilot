from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/trends", tags=["Trends"])

@router.api_route("/dexcom/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def dexcom_trends_removed(path: str):
    """Dexcom trend endpoints removed. Use HealthKit-based trend computation on the client or server-side using HealthKit exports."""
    raise HTTPException(status_code=status.HTTP_410_GONE, detail="Dexcom trends removed. Use HealthKit data instead.")
