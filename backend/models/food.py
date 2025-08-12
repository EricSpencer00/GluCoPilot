from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class Food(Base):
    __tablename__ = "food_entries"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)
    meal_type = Column(String, nullable=True)  # "breakfast", "lunch", "dinner", "snack"
    carbs = Column(Float)  # grams
    protein = Column(Float)  # grams
    fat = Column(Float)  # grams
    fiber = Column(Float, nullable=True)  # grams
    sugar = Column(Float, nullable=True)  # grams
    glycemic_index = Column(Integer, nullable=True)  # Scale of 0-100
    glycemic_load = Column(Float, nullable=True)
    calories = Column(Float)
    serving_size = Column(Float, nullable=True)
    serving_unit = Column(String, nullable=True)  # e.g., "g", "oz", "cup"
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    source = Column(String, default="manual")  # "manual", "myfitnesspal", "apple_health"
    meta_data = Column(JSON, nullable=True)  # For additional data from external sources
    
    # Derived property for convenience
    @property
    def total_carbs(self):
        return self.carbs if self.carbs is not None else 0
    
    # Relationships
    user = relationship("User", back_populates="food_entries")
