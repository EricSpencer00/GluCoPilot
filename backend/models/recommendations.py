from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float, Boolean
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Recommendation(Base):
    __tablename__ = "recommendations"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    recommendation_type = Column(String)  # e.g., "Insulin", "Food", "Activity"
    content = Column(Text)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    # Fields from previous update
    title = Column(String(128), nullable=True)
    category = Column(String(64), nullable=True)
    priority = Column(String(32), nullable=True)
    confidence_score = Column(Float, nullable=True)
    context_data = Column(Text, nullable=True)
    
    # New fields for user feedback
    is_helpful = Column(Boolean, nullable=True)  # User found this helpful
    user_rating = Column(Integer, nullable=True)  # 1-5 star rating
    user_feedback = Column(Text, nullable=True)  # Optional user comment
    is_implemented = Column(Boolean, nullable=True)  # User implemented this suggestion
    implementation_result = Column(Text, nullable=True)  # User's result after implementing
    
    # Action-oriented fields
    suggested_time = Column(DateTime, nullable=True)  # When to take this action
    action_taken = Column(Boolean, nullable=True)  # User marked as completed
    action_taken_time = Column(DateTime, nullable=True)  # When action was taken
    suggested_action = Column(Text, nullable=True)  # Specific actionable advice
    
    # Relationships
    user = relationship("User", back_populates="recommendations")
