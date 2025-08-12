from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Sleep(Base):
    __tablename__ = "sleep_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    duration_minutes = Column(Integer)
    quality = Column(Integer, nullable=True)  # Scale of 1-10
    deep_sleep_minutes = Column(Integer, nullable=True)
    light_sleep_minutes = Column(Integer, nullable=True)
    rem_sleep_minutes = Column(Integer, nullable=True)
    awake_minutes = Column(Integer, nullable=True)
    heart_rate_avg = Column(Integer, nullable=True)
    source = Column(String, default="manual")  # "manual", "apple_health", "google_fit", "fitbit"
    meta_data = Column(JSON, nullable=True)  # For additional data from external sources
    
    # Relationships
    user = relationship("User", back_populates="sleep_logs")
