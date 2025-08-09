from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from core.database import get_db
from models.insulin import Insulin
from schemas.insulin import InsulinCreate, InsulinOut
from fastapi import status
from datetime import datetime
from models.user import User
from api.routers.auth import get_current_user

router = APIRouter(tags=["insulin"])

@router.post("/log", response_model=InsulinOut, status_code=status.HTTP_201_CREATED)
def log_insulin(
    insulin: InsulinCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_insulin = Insulin(
        user_id=current_user.id,
        units=insulin.units,
        insulin_type=insulin.insulin_type,
        timestamp=insulin.timestamp or datetime.utcnow()
    )
    db.add(db_insulin)
    db.commit()
    db.refresh(db_insulin)
    return db_insulin


@router.get("/user", response_model=List[InsulinOut])
def get_user_insulin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Insulin).filter(Insulin.user_id == current_user.id).order_by(Insulin.timestamp.desc()).all()

# DELETE endpoint for insulin log
@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_insulin(id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    insulin = db.query(Insulin).filter(Insulin.id == id, Insulin.user_id == current_user.id).first()
    if not insulin:
        raise HTTPException(status_code=404, detail="Insulin log not found")
    db.delete(insulin)
    db.commit()
    return
