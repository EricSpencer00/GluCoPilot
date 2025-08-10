from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from ..dependencies import get_current_user, get_db
from ...models import activity, food
import xml.etree.ElementTree as ET

router = APIRouter(prefix="/apple-health", tags=["Apple Health"])

@router.post("/import")
def import_apple_health(file: UploadFile = File(...), user=Depends(get_current_user), db: Session = Depends(get_db)):
    # Parse XML file
    try:
        tree = ET.parse(file.file)
        root = tree.getroot()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid XML: {e}")

    # Get yesterday's date range
    today = datetime.now().date()
    yesterday = today - timedelta(days=1)
    start_dt = datetime.combine(yesterday, datetime.min.time())
    end_dt = datetime.combine(yesterday, datetime.max.time())

    # Parse activity and food records for yesterday
    activity_records = []
    food_records = []
    for record in root.findall('Record'):
        record_type = record.attrib.get('type', '')
        start_date = record.attrib.get('startDate', '')
        end_date = record.attrib.get('endDate', '')
        try:
            record_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        except Exception:
            continue
        if not (start_dt <= record_dt <= end_dt):
            continue
        # Activity
        if record_type.startswith('HKWorkoutTypeIdentifier') or 'Activity' in record_type:
            activity_records.append(record)
        # Food
        if record_type.startswith('HKDataTypeIdentifierDietary'):
            food_records.append(record)

    # Insert activity records
    for rec in activity_records:
        db.add(activity.Activity(
            user_id=user.id,
            activity_type=rec.attrib.get('workoutActivityType', 'Unknown'),
            duration_minutes=float(rec.attrib.get('duration', 0)),
            calories_burned=float(rec.attrib.get('totalEnergyBurned', 0)),
            timestamp=datetime.fromisoformat(rec.attrib.get('startDate').replace('Z', '+00:00')),
            source='apple_health',
            meta_data=rec.attrib
        ))
    # Insert food records
    for rec in food_records:
        db.add(food.Food(
            user_id=user.id,
            name=rec.attrib.get('foodType', 'Unknown'),
            carbs=float(rec.attrib.get('value', 0)) if 'Carbohydrates' in rec.attrib.get('type', '') else None,
            protein=float(rec.attrib.get('value', 0)) if 'Protein' in rec.attrib.get('type', '') else None,
            fat=float(rec.attrib.get('value', 0)) if 'Fat' in rec.attrib.get('type', '') else None,
            calories=float(rec.attrib.get('value', 0)) if 'Energy' in rec.attrib.get('type', '') else None,
            timestamp=datetime.fromisoformat(rec.attrib.get('startDate').replace('Z', '+00:00')),
            source='apple_health',
            meta_data=rec.attrib
        ))
    db.commit()
    return {"message": f"Imported {len(activity_records)} activity and {len(food_records)} food records for {yesterday}"}
