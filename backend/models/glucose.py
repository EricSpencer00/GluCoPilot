from sqlalchemy import Column, Integer, Float, DateTime, ForeignKey, String, Boolean
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class GlucoseReading(Base):
    __tablename__ = "glucose_readings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    value = Column(Float)  # in mg/dL
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    source = Column(String, default="manual")  # 'manual', 'cgm', 'glucometer'
    quality = Column(String, nullable=True)
    trend = Column(String, nullable=True)
    trend_rate = Column(Float, nullable=True)
    is_high_alert = Column(Boolean, default=False)
    is_low_alert = Column(Boolean, default=False)
    is_urgent_low = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="glucose_readings")
    
    @property
    def glucose_status(self):
        if self.value < 54:
            return "urgent_low"
        elif self.value < 70:
            return "low"
        elif self.value > 250:
            return "high"
        elif self.value > 180:
            return "elevated"
        else:
            return "normal"
    
    @property
    def is_in_range(self):
        return 70 <= self.value <= 180
