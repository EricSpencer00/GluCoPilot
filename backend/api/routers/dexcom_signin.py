from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/dexcom", tags=["Dexcom"])

@router.api_route("/signin/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def dexcom_signin_removed(path: str):
    raise HTTPException(status_code=status.HTTP_410_GONE, detail="Dexcom sign-in removed. Use HealthKit and Apple integrations instead.")
