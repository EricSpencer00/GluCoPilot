from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class MenstrualCycle(Base):
    __tablename__ = "menstrual_cycles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    start_date = Column(DateTime)
    end_date = Column(DateTime, nullable=True)
    cycle_length = Column(Integer, nullable=True)
    period_length = Column(Integer, nullable=True)
    symptoms = Column(String, nullable=True)
    flow_level = Column(Integer, nullable=True)  # Scale of 1-5
    notes = Column(String, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="menstrual_cycles")
