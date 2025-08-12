from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Insulin(Base):
    __tablename__ = "insulin_doses"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    units = Column(Float)  # insulin units
    insulin_type = Column(String)  # e.g., "Rapid", "Long"
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="insulin_doses")
