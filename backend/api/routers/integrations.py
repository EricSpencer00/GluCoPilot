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
from models.consent import HealthConsent
from schemas.auth import UserResponse
from services.auth import get_current_active_user
from utils.encryption import encrypt_password, decrypt_password
from services.myfitnesspal import MyFitnessPalService

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
    if not current_user.myfitnesspal_username and not (current_user.third_party_tokens and current_user.third_party_tokens.get('myfitnesspal')):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MyFitnessPal account not connected"
        )

    try:
        # Prefer token-based sync if available
        token = None
        if current_user.third_party_tokens and isinstance(current_user.third_party_tokens, dict):
            token = current_user.third_party_tokens.get('myfitnesspal')

        if token:
            # Use existing service that expects an access token
            service = MyFitnessPalService(token)
            # Fetch last 7 days by default
            from datetime import date, timedelta
            end_date = date.today()
            start_date = end_date - timedelta(days=7)
            entries = service.fetch_food_logs(str(start_date), str(end_date))

            # Process and store food entries if any
            food_items = entries.get('foods') if isinstance(entries, dict) else None
            inserted = 0
            if food_items and isinstance(food_items, list):
                for f in food_items:
                    try:
                        food = Food(
                            user_id=current_user.id,
                            name=f.get('name') or 'unknown',
                            meal_type=f.get('meal_type'),
                            carbs=f.get('carbs') or 0,
                            protein=f.get('protein') or 0,
                            fat=f.get('fat') or 0,
                            fiber=f.get('fiber'),
                            sugar=f.get('sugar'),
                            calories=f.get('calories') or 0,
                            serving_size=f.get('serving_size'),
                            serving_unit=f.get('serving_unit'),
                            timestamp=f.get('timestamp') or end_date,
                            source='myfitnesspal',
                            meta_data=f
                        )
                        db.add(food)
                        inserted += 1
                    except Exception:
                        continue
                db.commit()

            return {
                "status": "success",
                "message": "MyFitnessPal data synced successfully",
                "data": {"food_entries_inserted": inserted}
            }
        else:
            # We only have username/password stored (encrypted). For security and App Store compliance
            # we do not perform automated scraping in the main request thread. Return accepted and
            # schedule a background job (placeholder) to perform sync.
            # TODO: Hook into a background worker (Celery/RQ) to perform credential-based sync.
            return {
                "status": "accepted",
                "message": "MyFitnessPal sync scheduled. Please ensure you have a server-side worker configured to handle credential-based sync."
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
            # create or update HealthConsent
            existing = db.query(HealthConsent).filter(HealthConsent.user_id == current_user.id, HealthConsent.platform == 'apple_health').first()
            if not existing:
                hc = HealthConsent(user_id=current_user.id, platform='apple_health', granted=True, scope={'read': True})
                db.add(hc)
            else:
                existing.granted = True
                existing.timestamp = __import__('datetime').datetime.utcnow()

        elif platform == "google_fit":
            current_user.google_fit_authorized = True
            # store consent
            existing = db.query(HealthConsent).filter(HealthConsent.user_id == current_user.id, HealthConsent.platform == 'google_fit').first()
            if not existing:
                hc = HealthConsent(user_id=current_user.id, platform='google_fit', granted=True, scope={'read': True})
                db.add(hc)
            else:
                existing.granted = True
                existing.timestamp = __import__('datetime').datetime.utcnow()

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
            # remove or mark consent
            existing = db.query(HealthConsent).filter(HealthConsent.user_id == current_user.id, HealthConsent.platform == 'apple_health').first()
            if existing:
                existing.granted = False
                existing.timestamp = __import__('datetime').datetime.utcnow()
        elif platform == "google_fit":
            current_user.google_fit_authorized = False
            existing = db.query(HealthConsent).filter(HealthConsent.user_id == current_user.id, HealthConsent.platform == 'google_fit').first()
            if existing:
                existing.granted = False
                existing.timestamp = __import__('datetime').datetime.utcnow()

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
    """Sync data from health platform. Validates user consent and ingests into Activity, Sleep, HealthData."""
    # Require authorization flags and user privacy preference
    if (platform == "apple_health" and not current_user.apple_health_authorized) or \
       (platform == "google_fit" and not current_user.google_fit_authorized):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{platform} not authorized"
        )

    # Respect user privacy preferences if set
    prefs = current_user.privacy_preferences or {}
    if isinstance(prefs, dict) and prefs.get('share_health_data') is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User has disabled sharing of health data"
        )

    try:
        # Helpers
        import datetime as _dt
        def parse_iso(ts: str) -> _dt.datetime:
            if not ts:
                return _dt.datetime.utcnow()
            try:
                # strip trailing Z
                s = ts.rstrip('Z')
                return _dt.datetime.fromisoformat(s)
            except Exception:
                try:
                    return _dt.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S")
                except Exception:
                    return _dt.datetime.utcnow()

        MAX_ITEMS = 2000
        processed = {"activities": 0, "sleep": 0, "steps": 0, "health_metrics": 0}

        # Activities
        activities = data.get('activities') or []
        if isinstance(activities, list):
            to_insert = []
            for item in activities[:MAX_ITEMS]:
                try:
                    act = Activity(
                        user_id=current_user.id,
                        activity_type=item.get('type') or item.get('activity_type') or 'unknown',
                        duration_minutes=int((item.get('duration') or 0) / 60) if item.get('duration') else (item.get('duration_min') or 0),
                        intensity=item.get('intensity'),
                        calories_burned=float(item.get('calories') or item.get('calories_burned') or 0),
                        steps=int(item.get('steps')) if item.get('steps') else None,
                        heart_rate_avg=int(item.get('heartRate') or (item.get('heart_rate') and (sum(item.get('heart_rate'))/len(item.get('heart_rate'))) ) ) if item.get('heartRate') or item.get('heart_rate') else None,
                        timestamp=parse_iso(item.get('startDate') or item.get('timestamp')),
                        source=platform,
                        meta_data=item
                    )
                    to_insert.append(act)
                except Exception:
                    continue
            if to_insert:
                db.add_all(to_insert)
                processed['activities'] = len(to_insert)

        # Sleep
        sleep_list = data.get('sleep') or []
        if isinstance(sleep_list, list):
            to_insert = []
            for s in sleep_list[:MAX_ITEMS]:
                try:
                    start = parse_iso(s.get('startDate'))
                    end = parse_iso(s.get('endDate'))
                    duration_min = int((end - start).total_seconds() / 60)
                    sl = Sleep(
                        user_id=current_user.id,
                        start_time=start,
                        end_time=end,
                        duration_minutes=duration_min,
                        quality=int(s.get('quality')) if s.get('quality') is not None else None,
                        deep_sleep_minutes=int(s.get('deepSleepTime')/60) if s.get('deepSleepTime') else None,
                        rem_sleep_minutes=int(s.get('remSleepTime')/60) if s.get('remSleepTime') else None,
                        light_sleep_minutes=int(s.get('lightSleepTime')/60) if s.get('lightSleepTime') else None,
                        source=platform,
                        meta_data=s
                    )
                    to_insert.append(sl)
                except Exception:
                    continue
            if to_insert:
                db.add_all(to_insert)
                processed['sleep'] = len(to_insert)

        # Steps
        steps = data.get('steps') or []
        if isinstance(steps, list):
            to_insert = []
            for s in steps[:MAX_ITEMS]:
                try:
                    ts = parse_iso(s.get('date') or s.get('timestamp'))
                    count = float(s.get('count') or s.get('value') or 0)
                    hd = HealthData(
                        user_id=current_user.id,
                        data_type='Steps',
                        value=count,
                        unit='count',
                        timestamp=ts
                    )
                    to_insert.append(hd)
                except Exception:
                    continue
            if to_insert:
                db.add_all(to_insert)
                processed['steps'] = len(to_insert)

        # Weight
        weights = data.get('weight') or []
        if isinstance(weights, list):
            to_insert = []
            for w in weights[:MAX_ITEMS]:
                try:
                    ts = parse_iso(w.get('date') or w.get('timestamp'))
                    val = float(w.get('value') or w.get('weight') or 0)
                    hd = HealthData(
                        user_id=current_user.id,
                        data_type='Weight',
                        value=val,
                        unit='kg',
                        timestamp=ts
                    )
                    to_insert.append(hd)
                except Exception:
                    continue
            if to_insert:
                db.add_all(to_insert)
                processed['health_metrics'] += len(to_insert)

        # Heart rate
        hrs = data.get('heartRate') or []
        if isinstance(hrs, list):
            to_insert = []
            for h in hrs[:MAX_ITEMS]:
                try:
                    ts = parse_iso(h.get('date') or h.get('timestamp'))
                    val = float(h.get('value') or h.get('bpm') or 0)
                    hd = HealthData(
                        user_id=current_user.id,
                        data_type='HeartRate',
                        value=val,
                        unit='bpm',
                        timestamp=ts
                    )
                    to_insert.append(hd)
                except Exception:
                    continue
            if to_insert:
                db.add_all(to_insert)
                processed['health_metrics'] += len(to_insert)

        # Persist all inserted records
        db.commit()

        return {
            "status": "success",
            "message": f"{platform} data synced successfully",
            "data": processed
        }

    except Exception as e:
        logger.error(f"Error syncing health data: {str(e)}")
        db.rollback()
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
