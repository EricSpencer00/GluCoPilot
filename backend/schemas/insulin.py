from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class InsulinCreate(BaseModel):
    units: float
    insulin_type: Optional[str] = None
    timestamp: Optional[datetime] = None

class InsulinOut(BaseModel):
    id: int
    user_id: int
    units: float
    insulin_type: Optional[str] = None
    timestamp: datetime

    class Config:
        orm_mode = True
