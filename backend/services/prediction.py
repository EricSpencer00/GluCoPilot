from typing import List, Dict, Any, Optional, Union
import json
from datetime import datetime, timedelta
import asyncio
from sqlalchemy.orm import Session

from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from models.health_data import HealthData
from models.prediction import PredictionModel, GlucosePrediction
from ai.insights_engine import AIInsightsEngine
from core.config import settings
from utils.logging import get_logger

logger = get_logger(__name__)

class PredictionService:
    """Service for glucose prediction and analysis"""
    
    def __init__(self):
        self.ai_engine = AIInsightsEngine()
        self.initialized = False
    
    async def initialize(self):
        """Initialize prediction service dependencies (optional for lightweight engine)"""
        if self.initialized:
            return
        
        # Only initialize if the engine exposes an initialize method
        try:
            init_attr = getattr(self.ai_engine, "initialize", None)
            if callable(init_attr):
                if asyncio.iscoroutinefunction(init_attr):
                    await init_attr()
                else:
                    init_attr()
        except Exception as e:
            logger.warning(f"AI engine optional initialize skipped: {e}")
        
        self.initialized = True
        logger.debug("Prediction service initialized")
    
    async def generate_predictions(
        self, 
        user: User, 
        db: Session, 
        time_horizon_minutes: int = 30,
        include_activity: bool = True,
        include_food: bool = True
    ) -> Dict[str, Any]:
        """
        Generate glucose predictions for the specified time horizon
        
        Args:
            user: User to generate predictions for
            db: Database session
            time_horizon_minutes: How far into the future to predict (minutes)
            include_activity: Whether to include activity data in prediction
            include_food: Whether to include food data in prediction
            
        Returns:
            Dictionary containing prediction results and metadata
        """
        if not self.initialized:
            await self.initialize()
        
        logger.debug(f"Generating predictions for user {user.id}, horizon: {time_horizon_minutes}min")
        
        try:
            # Gather input data (last 24 hours)
            data = await self._gather_prediction_data(user, db)
            
            # Get current glucose state
            current_glucose = self._get_current_glucose_state(data)
            if not current_glucose:
                return {
                    "success": False,
                    "error": "Insufficient glucose data for prediction"
                }
            
            # Generate prediction
            prediction_result = await self._predict_glucose(
                user, 
                data, 
                time_horizon_minutes,
                include_activity,
                include_food
            )
            
            # Store prediction in database
            stored_prediction = self._store_prediction(user, db, prediction_result)
            
            # Format response
            response = {
                "success": True,
                "prediction": {
                    "id": stored_prediction.id,
                    "current_value": current_glucose.get("value"),
                    "current_time": current_glucose.get("timestamp").isoformat(),
                    "predicted_value": prediction_result.get("value"),
                    "target_time": prediction_result.get("timestamp").isoformat(),
                    "confidence_interval": [
                        prediction_result.get("lower_bound"),
                        prediction_result.get("upper_bound")
                    ],
                    "is_high_risk": prediction_result.get("is_high_risk", False),
                    "is_low_risk": prediction_result.get("is_low_risk", False),
                    "explanation": prediction_result.get("explanation", "")
                },
                "contributing_factors": prediction_result.get("factors", []),
                "metadata": {
                    "model_type": prediction_result.get("model_type", "LLM"),
                    "data_points_used": len(data.get("glucose", [])),
                    "created_at": datetime.utcnow().isoformat()
                }
            }
            
            return response
            
        except Exception as e:
            logger.error(f"Error generating predictions: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _gather_prediction_data(self, user: User, db: Session) -> Dict[str, List]:
        """Gather all relevant data for prediction"""
        
        # Time window for historical data (24 hours)
        start_time = datetime.utcnow() - timedelta(hours=24)
        
        # Get glucose readings
        glucose_readings = db.query(GlucoseReading)\
            .filter(GlucoseReading.user_id == user.id)\
            .filter(GlucoseReading.timestamp >= start_time)\
            .order_by(GlucoseReading.timestamp.desc())\
            .all()
        
        # Get insulin doses
        insulin_doses = db.query(Insulin)\
            .filter(Insulin.user_id == user.id)\
            .filter(Insulin.timestamp >= start_time)\
            .order_by(Insulin.timestamp.desc())\
            .all()
        
        # Get food entries
        food_entries = db.query(Food)\
            .filter(Food.user_id == user.id)\
            .filter(Food.timestamp >= start_time)\
            .order_by(Food.timestamp.desc())\
            .all()
        
        # Get activity data (steps, exercise, etc.)
        activity_data = db.query(HealthData)\
            .filter(HealthData.user_id == user.id)\
            .filter(HealthData.timestamp >= start_time)\
            .filter(HealthData.data_type.in_(["Steps", "Exercise", "HeartRate"]))\
            .order_by(HealthData.timestamp.desc())\
            .all()
        
        return {
            "glucose": glucose_readings,
            "insulin": insulin_doses,
            "food": food_entries,
            "activity": activity_data
        }
    
    def _get_current_glucose_state(self, data: Dict[str, List]) -> Dict[str, Any]:
        """Extract current glucose state from available data"""
        glucose_readings = data.get("glucose", [])
        
        if not glucose_readings:
            return None
        
        # Most recent reading
        latest_reading = glucose_readings[0]
        
        # Calculate rate of change from recent readings
        if len(glucose_readings) >= 3:
            recent_readings = glucose_readings[:3]  # 3 most recent readings
            time_diffs = [(r.timestamp - recent_readings[-1].timestamp).total_seconds() / 60 
                          for r in recent_readings]
            glucose_diffs = [r.value - recent_readings[-1].value for r in recent_readings]
            
            # Calculate slope (mg/dL per minute)
            if time_diffs[0] - time_diffs[-1] != 0:
                rate_of_change = (glucose_diffs[0] - glucose_diffs[-1]) / (time_diffs[0] - time_diffs[-1])
            else:
                rate_of_change = 0
        else:
            rate_of_change = latest_reading.trend_rate or 0
        
        return {
            "value": latest_reading.value,
            "timestamp": latest_reading.timestamp,
            "trend": latest_reading.trend,
            "rate_of_change": rate_of_change
        }
    
    async def _predict_glucose(
        self, 
        user: User, 
        data: Dict[str, List], 
        time_horizon_minutes: int,
        include_activity: bool,
        include_food: bool
    ) -> Dict[str, Any]:
        """
        Generate glucose prediction using available models
        
        For now, this uses a simplified algorithm. In the future, this would use
        a trained machine learning model.
        """
        current_state = self._get_current_glucose_state(data)
        if not current_state:
            raise ValueError("No current glucose data available")
        
        # Extract current glucose and rate of change
        current_glucose = current_state["value"]
        rate_of_change = current_state["rate_of_change"]  # mg/dL per minute
        
        # Basic linear projection
        projected_change = rate_of_change * time_horizon_minutes
        base_prediction = current_glucose + projected_change
        
        # Apply adjustments based on insulin, food and activity data
        adjustments = 0
        factors = []
        
        # Insulin effect (simplified)
        insulin_effect = self._calculate_insulin_effect(user, data, time_horizon_minutes)
        adjustments += insulin_effect["effect"]
        if insulin_effect["effect"] != 0:
            factors.append({
                "factor": "Insulin",
                "effect": insulin_effect["effect"],
                "description": insulin_effect["description"]
            })
        
        # Food effect
        if include_food:
            food_effect = self._calculate_food_effect(user, data, time_horizon_minutes)
            adjustments += food_effect["effect"]
            if food_effect["effect"] != 0:
                factors.append({
                    "factor": "Food",
                    "effect": food_effect["effect"],
                    "description": food_effect["description"]
                })
        
        # Activity effect
        if include_activity:
            activity_effect = self._calculate_activity_effect(user, data, time_horizon_minutes)
            adjustments += activity_effect["effect"]
            if activity_effect["effect"] != 0:
                factors.append({
                    "factor": "Activity",
                    "effect": activity_effect["effect"],
                    "description": activity_effect["description"]
                })
        
        # Calculate final prediction
        final_prediction = base_prediction + adjustments
        
        # Add confidence interval (wider for longer horizons)
        confidence_margin = max(10, time_horizon_minutes / 2)  # Simplified approach
        
        # Determine risk status
        is_high_risk = final_prediction > 180 and current_glucose <= 180
        is_low_risk = final_prediction < 70 and current_glucose >= 70
        
        # Generate explanation
        explanation = self._generate_prediction_explanation(
            current_glucose, 
            final_prediction, 
            factors, 
            time_horizon_minutes
        )
        
        return {
            "value": round(final_prediction, 1),
            "lower_bound": round(max(0, final_prediction - confidence_margin), 1),
            "upper_bound": round(final_prediction + confidence_margin, 1),
            "timestamp": datetime.utcnow() + timedelta(minutes=time_horizon_minutes),
            "is_high_risk": is_high_risk,
            "is_low_risk": is_low_risk,
            "model_type": "Hybrid",
            "factors": factors,
            "explanation": explanation
        }
    
    def _calculate_insulin_effect(
        self, 
        user: User, 
        data: Dict[str, List], 
        time_horizon_minutes: int
    ) -> Dict[str, Any]:
        """Calculate expected insulin effect within the prediction horizon"""
        insulin_doses = data.get("insulin", [])
        
        if not insulin_doses:
            return {"effect": 0, "description": "No recent insulin doses"}
        
        # Consider only insulin that is active in the prediction window
        active_insulin = []
        total_effect = 0
        descriptions = []
        
        for dose in insulin_doses:
            # Simplified insulin action curve
            # Assume rapid insulin starts working in 15 min, peaks at 1-2 hours, and lasts 4 hours
            minutes_since_dose = (datetime.utcnow() - dose.timestamp).total_seconds() / 60
            future_minutes = minutes_since_dose + time_horizon_minutes
            
            # Skip if insulin will be fully absorbed or hasn't started acting yet
            if future_minutes > 240 or minutes_since_dose < 0:
                continue
            
            # Calculate insulin effect at prediction time (simplified model)
            if dose.insulin_type.lower() in ["rapid", "bolus", "humalog", "novolog", "apidra"]:
                # Simplified trapezoid model for rapid insulin
                if future_minutes < 15:
                    effect_percent = 0  # Not active yet
                elif future_minutes < 60:
                    effect_percent = (future_minutes - 15) / 45 * 0.4  # Ramping up
                elif future_minutes < 180:
                    effect_percent = 0.4 + (future_minutes - 60) / 120 * 0.6  # Peak and early decline
                else:
                    effect_percent = 0.6 - (future_minutes - 180) / 60 * 0.6  # Trailing off
                
                # Estimate glucose drop
                # Using user's insulin sensitivity factor
                insulin_sensitivity = user.insulin_sensitivity_factor or 50  # mg/dL per unit
                expected_drop = dose.units * insulin_sensitivity * effect_percent
                
                total_effect -= expected_drop
                descriptions.append(f"{dose.units}u {dose.insulin_type} (active)")
            
            elif dose.insulin_type.lower() in ["long", "basal", "lantus", "levemir", "tresiba"]:
                # Long-acting insulin - more constant effect
                # Assume 24-hour duration with relatively flat profile
                if minutes_since_dose < 120:
                    effect_percent = minutes_since_dose / 120 * 0.04  # Ramping up
                elif minutes_since_dose < 1320:  # 22 hours
                    effect_percent = 0.04  # Stable effect
                else:
                    effect_percent = 0.04 * (1440 - minutes_since_dose) / 120  # Trailing off
                
                # Long-acting insulin effect (very approximate)
                basal_effect = dose.units * effect_percent * 5  # Smaller effect per unit-hour
                
                total_effect -= basal_effect
                descriptions.append(f"{dose.units}u {dose.insulin_type} (background)")
        
        if descriptions:
            description = f"Active insulin: {', '.join(descriptions)}"
        else:
            description = "No active insulin in prediction window"
        
        return {
            "effect": total_effect,
            "description": description
        }
    
    def _calculate_food_effect(
        self, 
        user: User, 
        data: Dict[str, List], 
        time_horizon_minutes: int
    ) -> Dict[str, Any]:
        """Calculate expected food effect within the prediction horizon"""
        food_entries = data.get("food", [])
        
        if not food_entries:
            return {"effect": 0, "description": "No recent food intake"}
        
        total_effect = 0
        descriptions = []
        
        # Simplistic carb digestion model
        for food in food_entries:
            minutes_since_meal = (datetime.utcnow() - food.timestamp).total_seconds() / 60
            future_minutes = minutes_since_meal + time_horizon_minutes
            
            # Skip if food was too long ago or hasn't started affecting blood sugar yet
            if future_minutes > 240 or minutes_since_meal < 0:
                continue
            
            # Carb effect - simplified model based on carb content and fat/protein
            # Consider user's insulin-to-carb ratio
            carb_ratio = user.insulin_carb_ratio or 15  # 1 unit per 15g carbs
            insulin_sensitivity = user.insulin_sensitivity_factor or 50  # mg/dL per unit
            
            # Calculate expected rise based on unconverted carbs
            if future_minutes < 30:
                carb_percent = future_minutes / 30 * 0.5  # Initial rapid rise
            elif future_minutes < 120:
                carb_percent = 0.5 + (future_minutes - 30) / 90 * 0.4  # Continued rise
            else:
                carb_percent = 0.9 - (future_minutes - 120) / 120 * 0.9  # Decline
            
            # Expected glucose rise from carbs
            carb_rise = (food.carbs / carb_ratio) * insulin_sensitivity * carb_percent
            
            # Adjustment for fat and protein (they slow absorption)
            if hasattr(food, 'fat') and hasattr(food, 'protein'):
                fat_protein_grams = food.fat + food.protein
                # Fat and protein delay peak glucose rise and extend duration
                if fat_protein_grams > 15:
                    delay_factor = min(1, fat_protein_grams / 50)  # Max 100% delay
                    carb_rise = carb_rise * (1 - delay_factor * 0.3)  # Reduce peak by up to 30%
                    descriptions.append(f"High fat/protein meal delaying carb absorption")
            
            total_effect += carb_rise
            descriptions.append(f"{food.carbs}g carbs from {food.name if hasattr(food, 'name') else 'meal'}")
        
        if descriptions:
            description = f"Food effect: {', '.join(descriptions)}"
        else:
            description = "No active food effect in prediction window"
        
        return {
            "effect": total_effect,
            "description": description
        }
    
    def _calculate_activity_effect(
        self, 
        user: User, 
        data: Dict[str, List], 
        time_horizon_minutes: int
    ) -> Dict[str, Any]:
        """Calculate expected physical activity effect within the prediction horizon"""
        activity_data = data.get("activity", [])
        
        if not activity_data:
            return {"effect": 0, "description": "No recent activity data"}
        
        # Filter for relevant activity types
        recent_steps = [entry for entry in activity_data if entry.data_type == "Steps"]
        exercise_entries = [entry for entry in activity_data if entry.data_type == "Exercise"]
        heart_rate_entries = [entry for entry in activity_data if entry.data_type == "HeartRate"]
        
        total_effect = 0
        descriptions = []
        
        # Exercise effect (can last several hours)
        for exercise in exercise_entries:
            minutes_since_exercise = (datetime.utcnow() - exercise.timestamp).total_seconds() / 60
            future_minutes = minutes_since_exercise + time_horizon_minutes
            
            # Skip if exercise is too old or hasn't started yet
            if future_minutes > 480 or minutes_since_exercise < 0:  # Effects can last up to 8 hours
                continue
            
            # Simplified exercise effect model
            # Immediate effect during and shortly after exercise
            if minutes_since_exercise < 60:
                effect_magnitude = -15  # Significant drop during/immediately after
            # Increased insulin sensitivity for several hours
            elif minutes_since_exercise < 240:
                effect_magnitude = -10  # Enhanced insulin sensitivity phase
            # Potential for delayed hypoglycemia
            else:
                effect_magnitude = -5  # Lingering effects
            
            # Adjust based on exercise intensity (if we have intensity data)
            intensity_factor = 1.0
            if hasattr(exercise, 'intensity') and exercise.intensity:
                intensity_factor = min(2.0, max(0.5, exercise.intensity / 5.0))  # Assuming 1-10 scale
            
            # Duration factor
            duration_minutes = getattr(exercise, 'duration_minutes', 30)
            duration_factor = min(3.0, max(0.5, duration_minutes / 30.0))
            
            exercise_effect = effect_magnitude * intensity_factor * duration_factor
            total_effect += exercise_effect
            
            descriptions.append(
                f"Exercise: {getattr(exercise, 'name', 'Activity')} "
                f"({int(minutes_since_exercise)}min ago)"
            )
        
        # Recent step count (for background activity)
        if recent_steps:
            last_hour_steps = sum(
                s.value for s in recent_steps 
                if (datetime.utcnow() - s.timestamp).total_seconds() < 3600
            )
            
            if last_hour_steps > 1000:
                step_effect = -5 * (last_hour_steps / 1000)
                total_effect += step_effect
                descriptions.append(f"Active: {int(last_hour_steps)} steps in last hour")
        
        # Heart rate (indicator of exertion)
        if heart_rate_entries:
            recent_hr = [
                hr for hr in heart_rate_entries 
                if (datetime.utcnow() - hr.timestamp).total_seconds() < 1800
            ]
            
            if recent_hr:
                avg_hr = sum(hr.value for hr in recent_hr) / len(recent_hr)
                resting_hr = 70  # Default resting HR
                
                if avg_hr > (resting_hr * 1.3):  # 30% above resting
                    hr_effect = -5 * ((avg_hr / resting_hr) - 1)
                    total_effect += hr_effect
                    descriptions.append(f"Elevated heart rate: {int(avg_hr)} bpm")
        
        if descriptions:
            description = f"Activity effect: {', '.join(descriptions)}"
        else:
            description = "No significant activity effect detected"
        
        return {
            "effect": total_effect,
            "description": description
        }
    
    def _generate_prediction_explanation(
        self, 
        current_glucose: float, 
        predicted_glucose: float,
        factors: List[Dict[str, Any]],
        time_horizon_minutes: int
    ) -> str:
        """Generate human-readable explanation for the prediction"""
        direction = "rise" if predicted_glucose > current_glucose else "fall"
        change_magnitude = abs(predicted_glucose - current_glucose)
        
        # Basic explanation
        explanation = (
            f"Your glucose is predicted to {direction} by {change_magnitude:.1f} mg/dL "
            f"over the next {time_horizon_minutes} minutes, "
            f"from {current_glucose:.1f} to {predicted_glucose:.1f} mg/dL."
        )
        
        # Add factor explanations
        if factors:
            factor_explanations = []
            for factor in factors:
                factor_explanations.append(f"{factor['description']}")
            
            explanation += f" This prediction considers: {'; '.join(factor_explanations)}."
        
        # Add risk assessment
        if predicted_glucose > 180:
            explanation += (
                f" This predicted level would be above your target range. "
                f"Consider checking more frequently and taking appropriate action."
            )
        elif predicted_glucose < 70:
            explanation += (
                f" This predicted level would be below your target range. "
                f"Consider consuming fast-acting carbohydrates to prevent hypoglycemia."
            )
        
        return explanation
    
    def _store_prediction(
        self, 
        user: User, 
        db: Session, 
        prediction_result: Dict[str, Any]
    ) -> GlucosePrediction:
        """Store prediction in the database"""
        # Get or create a prediction model record
        model = db.query(PredictionModel)\
            .filter(PredictionModel.user_id == user.id)\
            .filter(PredictionModel.model_type == prediction_result.get("model_type", "Hybrid"))\
            .first()
        
        if not model:
            model = PredictionModel(
                user_id=user.id,
                model_type=prediction_result.get("model_type", "Hybrid"),
                parameters=json.dumps({"version": "0.1"})
            )
            db.add(model)
            db.flush()
        
        # Create prediction record
        prediction = GlucosePrediction(
            user_id=user.id,
            model_id=model.id,
            prediction_time=datetime.utcnow(),
            target_time=prediction_result.get("timestamp"),
            predicted_value=prediction_result.get("value"),
            confidence_interval_lower=prediction_result.get("lower_bound"),
            confidence_interval_upper=prediction_result.get("upper_bound"),
            is_high_risk=prediction_result.get("is_high_risk", False),
            is_low_risk=prediction_result.get("is_low_risk", False),
            inputs=json.dumps({
                "factors": prediction_result.get("factors", [])
            }),
            explanation=prediction_result.get("explanation", "")
        )
        
        db.add(prediction)
        db.commit()
        
        return prediction
    
    async def validate_predictions(self, user: User, db: Session) -> Dict[str, Any]:
        """
        Validate past predictions against actual glucose values
        to assess model accuracy
        """
        # Get past predictions that should have actual values now
        cutoff_time = datetime.utcnow() - timedelta(minutes=10)
        past_predictions = db.query(GlucosePrediction)\
            .filter(GlucosePrediction.user_id == user.id)\
            .filter(GlucosePrediction.target_time < cutoff_time)\
            .filter(GlucosePrediction.actual_value == None)\
            .order_by(GlucosePrediction.target_time.desc())\
            .all()
        
        if not past_predictions:
            return {
                "validated": 0,
                "accuracy": None,
                "models": {}
            }
        
        # Get actual glucose readings for validation
        validated_count = 0
        total_error = 0
        model_stats = {}
        
        for prediction in past_predictions:
            # Find closest glucose reading to target time
            closest_reading = db.query(GlucoseReading)\
                .filter(GlucoseReading.user_id == user.id)\
                .filter(
                    GlucoseReading.timestamp >= prediction.target_time - timedelta(minutes=5),
                    GlucoseReading.timestamp <= prediction.target_time + timedelta(minutes=5)
                )\
                .order_by(
                    # Get reading closest to target time
                    db.func.abs(
                        db.func.extract('epoch', GlucoseReading.timestamp) - 
                        db.func.extract('epoch', prediction.target_time)
                    )
                )\
                .first()
            
            if closest_reading:
                # Update prediction with actual value
                prediction.actual_value = closest_reading.value
                
                # Calculate error
                error = abs(prediction.predicted_value - closest_reading.value)
                total_error += error
                validated_count += 1
                
                # Track model-specific stats
                model_type = db.query(PredictionModel).get(prediction.model_id).model_type
                if model_type not in model_stats:
                    model_stats[model_type] = {
                        "count": 0,
                        "total_error": 0
                    }
                model_stats[model_type]["count"] += 1
                model_stats[model_type]["total_error"] += error
        
        # Commit updates
        db.commit()
        
        # Calculate overall accuracy
        mean_absolute_error = total_error / validated_count if validated_count > 0 else None
        
        # Calculate model-specific accuracy
        for model_type in model_stats:
            stats = model_stats[model_type]
            stats["mean_error"] = stats["total_error"] / stats["count"]
        
        return {
            "validated": validated_count,
            "accuracy": mean_absolute_error,
            "models": model_stats
        }
    
    async def get_user_prediction_accuracy(self, user: User, db: Session) -> Dict[str, Any]:
        """Get overall prediction accuracy statistics for a user"""
        # Get validated predictions
        validated_predictions = db.query(GlucosePrediction)\
            .filter(GlucosePrediction.user_id == user.id)\
            .filter(GlucosePrediction.actual_value != None)\
            .all()
        
        if not validated_predictions:
            return {
                "count": 0,
                "mean_absolute_error": None,
                "accuracy_30": None,
                "high_risk_precision": None,
                "low_risk_precision": None
            }
        
        # Calculate accuracy metrics
        errors = [abs(p.predicted_value - p.actual_value) for p in validated_predictions]
        mean_absolute_error = sum(errors) / len(errors)
        
        # Accuracy within 30 mg/dL
        accuracy_30 = sum(1 for e in errors if e <= 30) / len(errors) * 100
        
        # High/low risk precision
        high_risk_predictions = [p for p in validated_predictions if p.is_high_risk]
        high_risk_precision = sum(
            1 for p in high_risk_predictions if p.actual_value > 180
        ) / len(high_risk_predictions) * 100 if high_risk_predictions else None
        
        low_risk_predictions = [p for p in validated_predictions if p.is_low_risk]
        low_risk_precision = sum(
            1 for p in low_risk_predictions if p.actual_value < 70
        ) / len(low_risk_predictions) * 100 if low_risk_predictions else None
        
        return {
            "count": len(validated_predictions),
            "mean_absolute_error": mean_absolute_error,
            "accuracy_30": accuracy_30,
            "high_risk_precision": high_risk_precision,
            "low_risk_precision": low_risk_precision
        }
