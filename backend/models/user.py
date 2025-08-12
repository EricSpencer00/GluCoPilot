from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Text, Float
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    
    # Dexcom integration
    dexcom_username = Column(String, nullable=True)
    dexcom_password = Column(String, nullable=True)
    dexcom_ous = Column(Boolean, default=False)  # Outside US flag
    
    # Third-party integrations
    myfitnesspal_username = Column(String, nullable=True)
    myfitnesspal_password = Column(String, nullable=True)
    apple_health_authorized = Column(Boolean, default=False)
    google_fit_authorized = Column(Boolean, default=False)
    fitbit_authorized = Column(Boolean, default=False)
    third_party_tokens = Column(JSON, nullable=True)  # Store OAuth tokens
    
    # Physical characteristics
    height_cm = Column(Float, nullable=True)
    weight_kg = Column(Float, nullable=True)
    birthdate = Column(DateTime, nullable=True)
    gender = Column(String, nullable=True)
    
    # Additional fields
    is_verified = Column(Boolean, default=False)
    last_login = Column(DateTime, nullable=True)
    refresh_token = Column(String, nullable=True)
    target_glucose_min = Column(Integer, nullable=True)
    target_glucose_max = Column(Integer, nullable=True)
    insulin_carb_ratio = Column(Integer, nullable=True)
    insulin_sensitivity_factor = Column(Integer, nullable=True)
    diabetes_type = Column(Integer, nullable=True)  # 1 or 2
    diagnosis_date = Column(DateTime, nullable=True)
    
    # User preferences
    notification_preferences = Column(JSON, nullable=True)
    privacy_preferences = Column(JSON, nullable=True)
    ai_feedback = Column(JSON, nullable=True)  # Store feedback on AI recommendations

    # Relationships
    glucose_readings = relationship("GlucoseReading", back_populates="user")
    insulin_doses = relationship("Insulin", back_populates="user")
    food_entries = relationship("Food", back_populates="user")
    analyses = relationship("Analysis", back_populates="user")
    recommendations = relationship("Recommendation", back_populates="user")
    health_data = relationship("HealthData", back_populates="user")
    prediction_models = relationship("PredictionModel", back_populates="user")
    glucose_predictions = relationship("GlucosePrediction", back_populates="user")
    
    # New relationships for additional data streams
    activity_logs = relationship("Activity", back_populates="user")
    sleep_logs = relationship("Sleep", back_populates="user")
    mood_logs = relationship("Mood", back_populates="user")
    medication_logs = relationship("Medication", back_populates="user")
    illness_logs = relationship("Illness", back_populates="user")
    menstrual_cycles = relationship("MenstrualCycle", back_populates="user")
