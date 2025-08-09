from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from core.database import get_db
from models.food import Food
from schemas.food import FoodCreate, FoodOut
from fastapi import status
from datetime import datetime
from models.user import User
from api.routers.auth import get_current_user

router = APIRouter(tags=["food"])

@router.post("/log", response_model=FoodOut, status_code=status.HTTP_201_CREATED)
def log_food(
    food: FoodCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_food = Food(
        user_id=current_user.id,
        carbs=food.carbs,
        name=food.name,
        timestamp=food.timestamp or datetime.utcnow()
    )
    db.add(db_food)
    db.commit()
    db.refresh(db_food)
    return db_food


@router.get("/user", response_model=List[FoodOut])
def get_user_food(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Food).filter(Food.user_id == current_user.id).order_by(Food.timestamp.desc()).all()

# DELETE endpoint for food log
@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_food(id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    food = db.query(Food).filter(Food.id == id, Food.user_id == current_user.id).first()
    if not food:
        raise HTTPException(status_code=404, detail="Food log not found")
    db.delete(food)
    db.commit()
    return
