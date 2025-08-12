from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Activity(Base):
    __tablename__ = "activity_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    activity_type = Column(String)  # e.g., "Walking", "Running", "Cycling"
    duration_minutes = Column(Integer)
    intensity = Column(String)  # "Low", "Moderate", "High"
    calories_burned = Column(Float, nullable=True)
    steps = Column(Integer, nullable=True)
    heart_rate_avg = Column(Integer, nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    source = Column(String, default="manual")  # "manual", "apple_health", "google_fit", "fitbit"
    meta_data = Column(JSON, nullable=True)  # For additional data from external sources
    
    # Relationships
    user = relationship("User", back_populates="activity_logs")
