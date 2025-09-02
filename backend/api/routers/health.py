from fastapi import APIRouter, HTTPException, Depends, Body, status
from sqlalchemy.orm import Session
from services.auth import get_current_active_user
from core.database import get_db
from models.user import User
from models.health_data import HealthData
from typing import Dict, Any, List
from utils.logging import get_logger
from datetime import datetime
from core.config import settings

router = APIRouter()
logger = get_logger(__name__)

@router.post("/sync")
async def sync_health_data(
    health_data: List[Dict[str, Any]] = Body(...),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Sync health data from Apple Health or other platforms"""
    logger.info(f"Health sync request from user {getattr(current_user, 'id', 'stateless')}")

    try:
        processed_count = 0

        for data_point in health_data:
            # Parse timestamp safely
            ts_raw = data_point.get("timestamp")
            try:
                ts = datetime.fromisoformat(ts_raw.replace('Z', '+00:00')) if isinstance(ts_raw, str) else datetime.utcnow()
            except Exception:
                ts = datetime.utcnow()

            if settings.USE_DATABASE:
                # Create and persist health data entry
                health_entry = HealthData(
                    user_id=current_user.id,
                    data_type=data_point.get("type", "unknown"),
                    value=data_point.get("value"),
                    unit=data_point.get("unit"),
                    source=data_point.get("source", "apple_health"),
                    timestamp=ts,
                    metadata=data_point.get("metadata", {})
                )

                db.add(health_entry)
            # In stateless mode we do not persist; still count processed points
            processed_count += 1

        if settings.USE_DATABASE:
            db.commit()

        return {
            "status": "success",
            "processed_count": processed_count,
            "message": f"Successfully processed {processed_count} health data points{' (not persisted in stateless mode)' if not settings.USE_DATABASE else ''}"
        }

    except Exception as e:
        logger.error(f"Error syncing health data: {str(e)}")
        if settings.USE_DATABASE:
            try:
                db.rollback()
            except Exception:
                logger.error("Failed to rollback DB transaction after health sync error")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process health data: {str(e)}"
        )
