from fastapi import APIRouter, HTTPException, Depends, Body, status
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from models.health_data import HealthData
from typing import Dict, Any, List
from utils.logging import get_logger
from datetime import datetime

router = APIRouter()
logger = get_logger(__name__)

@router.post("/sync")
async def sync_health_data(
    health_data: List[Dict[str, Any]] = Body(...),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync health data from Apple Health or other platforms"""
    logger.info(f"Health sync request from user {current_user.id}")
    
    try:
        processed_count = 0
        
        for data_point in health_data:
            # Create health data entry
            health_entry = HealthData(
                user_id=current_user.id,
                data_type=data_point.get("type", "unknown"),
                value=data_point.get("value"),
                unit=data_point.get("unit"),
                source=data_point.get("source", "apple_health"),
                timestamp=datetime.fromisoformat(data_point.get("timestamp", datetime.utcnow().isoformat()).replace('Z', '+00:00')),
                metadata=data_point.get("metadata", {})
            )
            
            db.add(health_entry)
            processed_count += 1
        
        db.commit()
        
        return {
            "status": "success",
            "processed_count": processed_count,
            "message": f"Successfully synced {processed_count} health data points"
        }
        
    except Exception as e:
        logger.error(f"Error syncing health data: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync health data: {str(e)}"
        )
