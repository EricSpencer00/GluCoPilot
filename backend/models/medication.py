from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Medication(Base):
    __tablename__ = "medication_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)
    dosage = Column(String)
    units = Column(String, nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    taken = Column(Boolean, default=True)
    notes = Column(String, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="medication_logs")

class Illness(Base):
    __tablename__ = "illness_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)
    severity = Column(Integer)  # Scale of 1-10
    symptoms = Column(String, nullable=True)
    start_date = Column(DateTime, default=datetime.datetime.utcnow)
    end_date = Column(DateTime, nullable=True)
    notes = Column(String, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="illness_logs")
