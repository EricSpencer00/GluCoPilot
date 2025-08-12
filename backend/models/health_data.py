from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class HealthData(Base):
    __tablename__ = "health_data"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    data_type = Column(String)  # e.g., "Weight", "Blood Pressure", "Steps"
    value = Column(Float)
    unit = Column(String)  # e.g., "kg", "mmHg", "count"
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="health_data")
