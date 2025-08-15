from sqlalchemy import Column, Integer, Boolean, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class HealthConsent(Base):
    __tablename__ = "health_consents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    platform = Column(String, nullable=False)  # e.g., 'apple_health', 'google_fit'
    granted = Column(Boolean, default=False)
    scope = Column(JSON, nullable=True)
    meta = Column(JSON, nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User")
