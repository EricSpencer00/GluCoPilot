from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class FoodCreate(BaseModel):
    carbs: float
    name: Optional[str] = None
    timestamp: Optional[datetime] = None

class FoodOut(BaseModel):
    id: int
    user_id: int
    carbs: float
    name: Optional[str] = None
    timestamp: datetime

    class Config:
        orm_mode = True
