from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class RecommendationOut(BaseModel):
    id: int
    recommendation_type: str
    content: str
    title: Optional[str]
    category: Optional[str]
    priority: Optional[str]
    confidence_score: Optional[float]
    context_data: Optional[Dict[str, Any]]
    timestamp: datetime

    class Config:
        orm_mode = True
