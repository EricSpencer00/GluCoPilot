from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from typing import List, Optional
import logging

from core.database import get_db
from models.user import User
from models.food import Food
from models.activity import Activity
from models.sleep import Sleep
from models.health_data import HealthData
from schemas.auth import UserResponse
from services.auth import get_current_active_user
from utils.encryption import encrypt_password, decrypt_password

router = APIRouter(
    prefix="/integrations",
    tags=["integrations"],
    responses={404: {"description": "Not found"}},
)

logger = logging.getLogger(__name__)

# MyFitnessPal Integration
@router.post("/myfitnesspal/connect")
async def connect_myfitnesspal(
    username: str = Body(...),
    password: str = Body(...),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Connect user's MyFitnessPal account"""
    try:
        # Encrypt credentials before storing
        encrypted_password = encrypt_password(password)
        
        # Update user with MyFitnessPal credentials
        current_user.myfitnesspal_username = username
        current_user.myfitnesspal_password = encrypted_password
        db.commit()
        
        return {"status": "success", "message": "MyFitnessPal account connected successfully"}
    except Exception as e:
        logger.error(f"Error connecting MyFitnessPal account: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to connect MyFitnessPal account"
        )

@router.post("/myfitnesspal/disconnect")
async def disconnect_myfitnesspal(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Disconnect user's MyFitnessPal account"""
    try:
        current_user.myfitnesspal_username = None
        current_user.myfitnesspal_password = None
        db.commit()
        
        return {"status": "success", "message": "MyFitnessPal account disconnected successfully"}
    except Exception as e:
        logger.error(f"Error disconnecting MyFitnessPal account: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to disconnect MyFitnessPal account"
        )

@router.post("/myfitnesspal/sync")
async def sync_myfitnesspal_data(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync data from user's MyFitnessPal account"""
    if not current_user.myfitnesspal_username or not current_user.myfitnesspal_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MyFitnessPal account not connected"
        )
    
    try:
        # Placeholder for actual MyFitnessPal API integration
        # In a real implementation, we would:
        # 1. Decrypt the password
        # 2. Use a MyFitnessPal API client to fetch data
        # 3. Process and store the data
        
        # For now, return a success message
        return {
            "status": "success", 
            "message": "MyFitnessPal data sync initiated",
            "data": {
                "food_entries": 0,
                "activity_entries": 0
            }
        }
    except Exception as e:
        logger.error(f"Error syncing MyFitnessPal data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to sync MyFitnessPal data"
        )

# Apple Health / Google Fit Integration
@router.post("/health/authorize")
async def authorize_health_platform(
    platform: str = Body(...),  # "apple_health" or "google_fit"
    auth_token: Optional[str] = Body(None),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Authorize health platform integration"""
    try:
        if platform == "apple_health":
            current_user.apple_health_authorized = True
        elif platform == "google_fit":
            current_user.google_fit_authorized = True
            
            # Store OAuth token if provided
            if auth_token and not current_user.third_party_tokens:
                current_user.third_party_tokens = {"google_fit": auth_token}
            elif auth_token and current_user.third_party_tokens:
                tokens = current_user.third_party_tokens
                tokens["google_fit"] = auth_token
                current_user.third_party_tokens = tokens
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported health platform"
            )
            
        db.commit()
        
        return {"status": "success", "message": f"{platform} authorized successfully"}
    except Exception as e:
        logger.error(f"Error authorizing health platform: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to authorize {platform}"
        )

@router.post("/health/revoke")
async def revoke_health_platform(
    platform: str = Body(...),  # "apple_health" or "google_fit"
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Revoke health platform integration"""
    try:
        if platform == "apple_health":
            current_user.apple_health_authorized = False
        elif platform == "google_fit":
            current_user.google_fit_authorized = False
            
            # Remove OAuth token if stored
            if current_user.third_party_tokens and "google_fit" in current_user.third_party_tokens:
                tokens = current_user.third_party_tokens
                tokens.pop("google_fit", None)
                current_user.third_party_tokens = tokens
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported health platform"
            )
            
        db.commit()
        
        return {"status": "success", "message": f"{platform} authorization revoked"}
    except Exception as e:
        logger.error(f"Error revoking health platform: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to revoke {platform} authorization"
        )

@router.post("/health/sync")
async def sync_health_data(
    data: dict = Body(...),
    platform: str = Body(...),  # "apple_health" or "google_fit"
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync data from health platform"""
    if (platform == "apple_health" and not current_user.apple_health_authorized) or \
       (platform == "google_fit" and not current_user.google_fit_authorized):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{platform} not authorized"
        )
    
    try:
        # Process incoming health data
        # This is a placeholder for actual implementation
        
        processed = {
            "activities": 0,
            "sleep": 0,
            "steps": 0,
            "health_metrics": 0
        }
        
        # Return success with counts of processed data
        return {
            "status": "success", 
            "message": f"{platform} data synced successfully",
            "data": processed
        }
    except Exception as e:
        logger.error(f"Error syncing health data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync {platform} data"
        )

# Integration Status
@router.get("/status")
async def get_integration_status(
    current_user: User = Depends(get_current_active_user)
):
    """Get status of all integrations for the current user"""
    return {
        "dexcom": current_user.dexcom_username is not None,
        "myfitnesspal": current_user.myfitnesspal_username is not None,
        "apple_health": current_user.apple_health_authorized,
        "google_fit": current_user.google_fit_authorized
    }
