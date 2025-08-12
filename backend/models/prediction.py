from sqlalchemy import Column, Integer, Float, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from core.database import Base
import datetime

class PredictionModel(Base):
    __tablename__ = "prediction_models"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    model_type = Column(String)  # "LLM", "LSTM", "XGBoost", etc.
    accuracy = Column(Float, nullable=True)  # Model accuracy metric
    parameters = Column(Text, nullable=True)  # JSON string of model parameters
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="prediction_models")
    predictions = relationship("GlucosePrediction", back_populates="model")

class GlucosePrediction(Base):
    __tablename__ = "glucose_predictions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    model_id = Column(Integer, ForeignKey("prediction_models.id"))
    prediction_time = Column(DateTime, default=datetime.datetime.utcnow)  # When the prediction was made
    target_time = Column(DateTime)  # Time in the future this prediction is for
    predicted_value = Column(Float)  # Predicted glucose value in mg/dL
    confidence_interval_lower = Column(Float, nullable=True)
    confidence_interval_upper = Column(Float, nullable=True)
    is_high_risk = Column(Boolean, default=False)  # Prediction indicates high glucose risk
    is_low_risk = Column(Boolean, default=False)   # Prediction indicates low glucose risk
    actual_value = Column(Float, nullable=True)  # The actual glucose value once known
    inputs = Column(Text, nullable=True)  # JSON string of input data used for prediction
    explanation = Column(Text, nullable=True)  # Explanation of the prediction factors
    
    # Relationships
    user = relationship("User", back_populates="glucose_predictions")
    model = relationship("PredictionModel", back_populates="predictions")
    
    @property
    def prediction_accuracy(self):
        """Calculate the accuracy of the prediction once actual value is known"""
        if self.actual_value is None:
            return None
        return abs(self.predicted_value - self.actual_value)
    
    @property
    def prediction_status(self):
        """Get the status of the prediction"""
        if self.target_time > datetime.datetime.utcnow():
            return "pending"  # Future prediction
        elif self.actual_value is None:
            return "unmeasured"  # Past prediction time but no actual value recorded
        else:
            return "completed"  # Past prediction with actual value recorded
