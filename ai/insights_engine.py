import os
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import json
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline
from sentence_transformers import SentenceTransformer
import requests
import numpy as np
from sqlalchemy.orm import Session

from core.config import settings
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from models.recommendations import Recommendation
from models.activity import Activity
from models.sleep import Sleep
from models.mood import Mood
from models.medication import Medication, Illness
from models.menstrual_cycle import MenstrualCycle
from models.health_data import HealthData
from utils.logging import get_logger

logger = get_logger(__name__)

class AIInsightsEngine:
    """Core AI engine for generating diabetes management insights"""
    
    def __init__(self):
        self.model_name = settings.MODEL_NAME
        self.tokenizer = None
        self.model = None
        self.embedding_model = None
        self.generator = None
        self.initialized = False
    
    async def initialize(self):
        """Initialize AI models"""
        if self.initialized:
            return
        try:
            logger.info("Initializing AI models...")
            if settings.MODEL_NAME == "openai/gpt-oss-20b":
                # No local pipeline, will use Inference API
                self.generator = None
            elif settings.USE_LOCAL_MODEL and os.path.exists(settings.LOCAL_MODEL_PATH):
                self._load_local_model()
            else:
                self._load_huggingface_model()
            self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
            self.initialized = True
            logger.info("AI models initialized successfully")
        except Exception as e:
            logger.error(f"Error initializing AI models: {str(e)}")
            raise
    
    def _load_local_model(self):
        """Load local model"""
        logger.info(f"Loading local model from {settings.LOCAL_MODEL_PATH}")
        self.tokenizer = AutoTokenizer.from_pretrained(settings.LOCAL_MODEL_PATH)
        self.model = AutoModelForCausalLM.from_pretrained(
            settings.LOCAL_MODEL_PATH,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto" if torch.cuda.is_available() else None
        )
        self.generator = pipeline(
            "text-generation",
            model=self.model,
            tokenizer=self.tokenizer,
            max_length=512,
            temperature=0.7,
            do_sample=True
        )
    
    def _load_huggingface_model(self):
        """Load model from Hugging Face"""
        logger.info(f"Loading Hugging Face model: {self.model_name}")
        self.generator = pipeline(
            "text-generation",
            model=self.model_name,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto" if torch.cuda.is_available() else None
        )
    
    async def generate_recommendations(
        self,
        user: User,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        activity_data: List[Activity] = None,
        sleep_data: List[Sleep] = None,
        mood_data: List[Mood] = None,
        medication_data: List[Medication] = None,
        illness_data: List[Illness] = None,
        menstrual_cycle_data: List[MenstrualCycle] = None,
        health_data: List[HealthData] = None,
        db: Session = None
    ) -> List[Dict[str, Any]]:
        """Generate personalized recommendations based on user data from multiple streams"""
        
        if not self.initialized:
            await self.initialize()
        
        logger.info(f"Generating comprehensive recommendations for user {user.id}")
        
        # Initialize empty lists for any missing data
        activity_data = activity_data or []
        sleep_data = sleep_data or []
        mood_data = mood_data or []
        medication_data = medication_data or []
        illness_data = illness_data or []
        menstrual_cycle_data = menstrual_cycle_data or []
        health_data = health_data or []
        
        try:
            # Analyze patterns from all data streams
            patterns = await self._analyze_all_patterns(
                glucose_data, 
                insulin_data, 
                food_data,
                activity_data,
                sleep_data,
                mood_data,
                medication_data,
                illness_data,
                menstrual_cycle_data,
                health_data
            )
            
            # Create comprehensive context for AI model
            context = self._create_comprehensive_context(
                user, 
                patterns, 
                glucose_data, 
                insulin_data, 
                food_data,
                activity_data,
                sleep_data,
                mood_data,
                medication_data,
                illness_data,
                menstrual_cycle_data,
                health_data
            )
            
            # Generate recommendations using AI
            ai_recommendations = await self._generate_ai_recommendations(context)
            
            # Process and validate recommendations
            processed_recommendations = self._process_recommendations(ai_recommendations, user.id)
            
            # Store recommendations in database with enhanced fields
            stored_recommendations = []
            now = datetime.utcnow()
            
            for rec_data in processed_recommendations:
                # Calculate a suggested time for this recommendation if possible
                suggested_time = self._calculate_suggested_time(rec_data, now)
                
                recommendation = Recommendation(
                    user_id=user.id,
                    recommendation_type=rec_data.get('category', 'general'),
                    content=rec_data.get('description', ''),
                    title=rec_data.get('title'),
                    category=rec_data.get('category'),
                    priority=rec_data.get('priority'),
                    confidence_score=rec_data.get('confidence', 0.8),
                    context_data=json.dumps(rec_data.get('context', {})),
                    suggested_time=suggested_time,
                    suggested_action=rec_data.get('action', '')
                )
                db.add(recommendation)
                stored_recommendations.append(recommendation)
            
            db.commit()
            logger.info(f"Generated {len(stored_recommendations)} comprehensive recommendations")
            
            # Return all fields for API response
            return [
                {
                    'id': rec.id,
                    'recommendation_type': rec.recommendation_type,
                    'content': rec.content,
                    'title': rec.title,
                    'category': rec.category,
                    'priority': rec.priority,
                    'confidence_score': rec.confidence_score,
                    'context_data': json.loads(rec.context_data) if rec.context_data else {},
                    'timestamp': rec.timestamp.isoformat() if rec.timestamp else None,
                    'suggested_time': rec.suggested_time.isoformat() if rec.suggested_time else None,
                    'suggested_action': rec.suggested_action,
                    'action_taken': rec.action_taken
                }
                for rec in stored_recommendations
            ]
        
        except Exception as e:
            logger.error(f"Error generating comprehensive recommendations: {str(e)}")
            if db:
                db.rollback()
            return []
            
    def _calculate_suggested_time(self, recommendation_data, now):
        """Calculate a suggested time for when this recommendation should be implemented"""
        category = recommendation_data.get('category', '').lower()
        
        if 'insulin' in category and 'pre-meal' in recommendation_data.get('description', '').lower():
            # Suggest before next meal (roughly 1-3 hours from now depending on time of day)
            hour = now.hour
            if 5 <= hour < 10:  # Morning
                return now + timedelta(hours=1)  # Breakfast soon
            elif 10 <= hour < 14:  # Late morning/early afternoon
                return now + timedelta(hours=2)  # Lunch soon
            elif 16 <= hour < 20:  # Evening
                return now + timedelta(hours=1)  # Dinner soon
            else:
                return now + timedelta(hours=3)  # Next meal further away
        
        elif 'exercise' in category:
            # Exercise recommendations typically for today or tomorrow
            hour = now.hour
            if hour < 16:  # Still early in the day
                return now + timedelta(hours=3)  # Later today
            else:
                return datetime(now.year, now.month, now.day, 10, 0) + timedelta(days=1)  # Tomorrow morning
        
        elif 'sleep' in category:
            # Sleep recommendations for tonight
            return datetime(now.year, now.month, now.day, 21, 0)  # 9 PM tonight
        
        elif 'monitoring' in category:
            # Monitoring recommendations soon
            return now + timedelta(hours=1)
        
        # Default: suggest implementing in the next 3 hours
        return now + timedelta(hours=3)
    
    async def _analyze_all_patterns(
        self,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        activity_data: List[Activity],
        sleep_data: List[Sleep],
        mood_data: List[Mood],
        medication_data: List[Medication],
        illness_data: List[Illness],
        menstrual_cycle_data: List[MenstrualCycle],
        health_data: List[HealthData]
    ) -> Dict[str, Any]:
        """Analyze patterns from all data streams"""
        
        patterns = {
            'glucose_patterns': self._analyze_glucose_patterns(glucose_data),
            'meal_patterns': self._analyze_meal_patterns(glucose_data, food_data),
            'insulin_patterns': self._analyze_insulin_patterns(glucose_data, insulin_data),
            'time_patterns': self._analyze_time_patterns(glucose_data),
            'variability': self._analyze_variability(glucose_data),
            'activity_patterns': self._analyze_activity_patterns(glucose_data, activity_data),
            'sleep_patterns': self._analyze_sleep_patterns(glucose_data, sleep_data),
            'mood_patterns': self._analyze_mood_patterns(glucose_data, mood_data),
            'medication_patterns': self._analyze_medication_patterns(glucose_data, medication_data),
            'illness_patterns': self._analyze_illness_patterns(glucose_data, illness_data),
            'menstrual_patterns': self._analyze_menstrual_patterns(glucose_data, menstrual_cycle_data),
            'correlations': self._analyze_correlations(glucose_data, insulin_data, food_data, activity_data, sleep_data, mood_data)
        }
        
        return patterns
        
    def _analyze_activity_patterns(self, glucose_data: List[GlucoseReading], activity_data: List[Activity]) -> Dict[str, Any]:
        """Analyze activity-related glucose patterns"""
        if not activity_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for activity in activity_data:
            activity_time = activity.timestamp
            
            # Get glucose readings 0-4 hours after activity
            post_activity_readings = [
                reading for reading in glucose_data
                if activity_time < reading.timestamp <= activity_time + timedelta(hours=4)
            ]
            
            if post_activity_readings:
                pre_activity_reading = None
                for reading in glucose_data:
                    if reading.timestamp <= activity_time:
                        pre_activity_reading = reading
                        break
                        
                if pre_activity_reading:
                    min_glucose = min(reading.value for reading in post_activity_readings)
                    glucose_drop = pre_activity_reading.value - min_glucose
                    
                    patterns[f"activity_{activity.id}"] = {
                        'type': activity.activity_type,
                        'intensity': activity.intensity,
                        'duration': activity.duration_minutes,
                        'glucose_drop': glucose_drop,
                        'drop_per_minute': glucose_drop / activity.duration_minutes if activity.duration_minutes > 0 else 0,
                        'time_to_lowest': min([(reading.timestamp - activity_time).total_seconds() / 60 
                                             for reading in post_activity_readings 
                                             if reading.value == min_glucose], default=0)
                    }
        
        # Overall activity impact
        if patterns:
            activities_by_type = {}
            for key, data in patterns.items():
                activity_type = data['type']
                if activity_type not in activities_by_type:
                    activities_by_type[activity_type] = []
                activities_by_type[activity_type].append(data)
            
            # Calculate average impact by activity type
            activity_impacts = {}
            for activity_type, activities in activities_by_type.items():
                avg_glucose_drop = sum(activity['glucose_drop'] for activity in activities) / len(activities)
                activity_impacts[activity_type] = {
                    'avg_glucose_drop': avg_glucose_drop,
                    'count': len(activities)
                }
            
            patterns['activity_impacts'] = activity_impacts
            
        return patterns
        
    def _analyze_sleep_patterns(self, glucose_data: List[GlucoseReading], sleep_data: List[Sleep]) -> Dict[str, Any]:
        """Analyze sleep-related glucose patterns"""
        if not sleep_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for sleep in sleep_data:
            sleep_start = sleep.start_time
            sleep_end = sleep.end_time
            
            if not sleep_start or not sleep_end:
                continue
                
            # Get glucose readings during sleep
            during_sleep_readings = [
                reading for reading in glucose_data
                if sleep_start <= reading.timestamp <= sleep_end
            ]
            
            # Get glucose readings after waking
            post_wake_readings = [
                reading for reading in glucose_data
                if sleep_end < reading.timestamp <= sleep_end + timedelta(hours=3)
            ]
            
            if during_sleep_readings:
                # Sleep stability
                values = [reading.value for reading in during_sleep_readings]
                
                patterns[f"sleep_{sleep.id}"] = {
                    'duration_hours': sleep.duration_minutes / 60 if sleep.duration_minutes else 0,
                    'quality': sleep.quality,
                    'avg_glucose': np.mean(values),
                    'stability': np.std(values),
                    'glucose_range': max(values) - min(values) if values else 0
                }
                
                # Check for dawn phenomenon
                if post_wake_readings:
                    last_sleep_glucose = during_sleep_readings[-1].value if during_sleep_readings else None
                    first_wake_glucose = post_wake_readings[0].value if post_wake_readings else None
                    
                    if last_sleep_glucose and first_wake_glucose:
                        patterns[f"sleep_{sleep.id}"]['wake_glucose_change'] = first_wake_glucose - last_sleep_glucose
                        patterns[f"sleep_{sleep.id}"]['dawn_phenomenon'] = first_wake_glucose - last_sleep_glucose > 20
        
        # Overall sleep impact
        if patterns:
            sleep_records = [data for key, data in patterns.items() if key.startswith('sleep_')]
            
            if sleep_records:
                # Sleep duration impact
                short_sleeps = [s for s in sleep_records if s['duration_hours'] < 6]
                normal_sleeps = [s for s in sleep_records if 6 <= s['duration_hours'] <= 8]
                long_sleeps = [s for s in sleep_records if s['duration_hours'] > 8]
                
                patterns['sleep_impacts'] = {
                    'short_sleep_avg_glucose': np.mean([s['avg_glucose'] for s in short_sleeps]) if short_sleeps else 0,
                    'normal_sleep_avg_glucose': np.mean([s['avg_glucose'] for s in normal_sleeps]) if normal_sleeps else 0,
                    'long_sleep_avg_glucose': np.mean([s['avg_glucose'] for s in long_sleeps]) if long_sleeps else 0,
                    'dawn_phenomenon_frequency': len([s for s in sleep_records if s.get('dawn_phenomenon', False)]) / len(sleep_records) if sleep_records else 0
                }
        
        return patterns
        
    def _analyze_mood_patterns(self, glucose_data: List[GlucoseReading], mood_data: List[Mood]) -> Dict[str, Any]:
        """Analyze mood-related glucose patterns"""
        if not mood_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for mood in mood_data:
            mood_time = mood.timestamp
            
            # Get glucose readings around mood log (2 hours before, 2 hours after)
            surrounding_readings = [
                reading for reading in glucose_data
                if mood_time - timedelta(hours=2) <= reading.timestamp <= mood_time + timedelta(hours=2)
            ]
            
            if surrounding_readings:
                values = [reading.value for reading in surrounding_readings]
                
                patterns[f"mood_{mood.id}"] = {
                    'rating': mood.rating,
                    'tags': mood.tags.split(',') if mood.tags else [],
                    'avg_glucose': np.mean(values),
                    'variability': np.std(values)
                }
        
        # Group by mood rating
        mood_groups = {}
        for key, data in patterns.items():
            if key.startswith('mood_'):
                rating = data['rating']
                if rating not in mood_groups:
                    mood_groups[rating] = []
                mood_groups[rating].append(data)
        
        # Calculate glucose averages by mood rating
        mood_impacts = {}
        for rating, moods in mood_groups.items():
            avg_glucose = sum(mood['avg_glucose'] for mood in moods) / len(moods) if moods else 0
            mood_impacts[str(rating)] = {
                'avg_glucose': avg_glucose,
                'count': len(moods)
            }
            
        patterns['mood_impacts'] = mood_impacts
        
        return patterns
        
    def _analyze_medication_patterns(self, glucose_data: List[GlucoseReading], medication_data: List[Medication]) -> Dict[str, Any]:
        """Analyze medication-related glucose patterns"""
        if not medication_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for medication in medication_data:
            med_time = medication.timestamp
            
            # Get glucose readings 0-8 hours after medication
            post_med_readings = [
                reading for reading in glucose_data
                if med_time < reading.timestamp <= med_time + timedelta(hours=8)
            ]
            
            if post_med_readings:
                values = [reading.value for reading in post_med_readings]
                
                patterns[f"medication_{medication.id}"] = {
                    'name': medication.name,
                    'dosage': medication.dosage,
                    'taken': medication.taken,
                    'avg_glucose': np.mean(values),
                    'max_glucose': max(values),
                    'min_glucose': min(values)
                }
        
        # Group by medication name
        med_groups = {}
        for key, data in patterns.items():
            if key.startswith('medication_'):
                name = data['name']
                if name not in med_groups:
                    med_groups[name] = []
                med_groups[name].append(data)
        
        # Calculate average impact by medication
        med_impacts = {}
        for name, meds in med_groups.items():
            avg_glucose = sum(med['avg_glucose'] for med in meds) / len(meds) if meds else 0
            med_impacts[name] = {
                'avg_glucose': avg_glucose,
                'count': len(meds)
            }
            
        patterns['medication_impacts'] = med_impacts
        
        return patterns
        
    def _analyze_illness_patterns(self, glucose_data: List[GlucoseReading], illness_data: List[Illness]) -> Dict[str, Any]:
        """Analyze illness-related glucose patterns"""
        if not illness_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for illness in illness_data:
            start_date = illness.start_date
            end_date = illness.end_date or datetime.utcnow()
            
            # Get glucose readings during illness
            during_illness = [
                reading for reading in glucose_data
                if start_date <= reading.timestamp <= end_date
            ]
            
            # Get baseline glucose (2 weeks before illness)
            baseline_period = [
                reading for reading in glucose_data
                if start_date - timedelta(days=14) <= reading.timestamp < start_date
            ]
            
            if during_illness:
                illness_values = [reading.value for reading in during_illness]
                baseline_values = [reading.value for reading in baseline_period]
                
                baseline_avg = np.mean(baseline_values) if baseline_values else 0
                
                patterns[f"illness_{illness.id}"] = {
                    'name': illness.name,
                    'severity': illness.severity,
                    'duration_days': (end_date - start_date).days,
                    'avg_glucose': np.mean(illness_values),
                    'max_glucose': max(illness_values),
                    'min_glucose': min(illness_values),
                    'glucose_increase': np.mean(illness_values) - baseline_avg if baseline_values else 0,
                    'variability': np.std(illness_values)
                }
        
        return patterns
        
    def _analyze_menstrual_patterns(self, glucose_data: List[GlucoseReading], menstrual_data: List[MenstrualCycle]) -> Dict[str, Any]:
        """Analyze menstrual cycle-related glucose patterns"""
        if not menstrual_data or not glucose_data:
            return {}
            
        patterns = {}
        
        for cycle in menstrual_data:
            start_date = cycle.start_date
            end_date = cycle.end_date or (start_date + timedelta(days=cycle.period_length or 5))
            
            # Get glucose readings during period
            during_period = [
                reading for reading in glucose_data
                if start_date <= reading.timestamp <= end_date
            ]
            
            # Get glucose readings in luteal phase (7-14 days after period)
            luteal_start = end_date
            luteal_end = luteal_start + timedelta(days=7)
            luteal_phase = [
                reading for reading in glucose_data
                if luteal_start <= reading.timestamp <= luteal_end
            ]
            
            if during_period:
                period_values = [reading.value for reading in during_period]
                luteal_values = [reading.value for reading in luteal_phase]
                
                patterns[f"cycle_{cycle.id}"] = {
                    'period_length': cycle.period_length,
                    'period_avg_glucose': np.mean(period_values),
                    'period_variability': np.std(period_values),
                    'luteal_avg_glucose': np.mean(luteal_values) if luteal_values else 0,
                    'glucose_change': np.mean(luteal_values) - np.mean(period_values) if luteal_values and period_values else 0
                }
        
        return patterns
        
    def _analyze_correlations(
        self,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        activity_data: List[Activity],
        sleep_data: List[Sleep],
        mood_data: List[Mood]
    ) -> Dict[str, Any]:
        """Identify correlations between different data streams"""
        correlations = {}
        
        # No data to correlate
        if not glucose_data:
            return correlations
        
        # Minimum threshold for correlation analysis
        if len(glucose_data) < 10:
            return correlations
            
        # 1. Food & Activity
        if food_data and activity_data:
            food_activity_impact = self._correlate_food_and_activity(glucose_data, food_data, activity_data)
            if food_activity_impact:
                correlations['food_activity'] = food_activity_impact
                
        # 2. Sleep & Morning Glucose
        if sleep_data:
            sleep_glucose_impact = self._correlate_sleep_and_morning_glucose(glucose_data, sleep_data)
            if sleep_glucose_impact:
                correlations['sleep_morning_glucose'] = sleep_glucose_impact
                
        # 3. Mood & Glucose Variability
        if mood_data:
            mood_glucose_impact = self._correlate_mood_and_glucose(glucose_data, mood_data)
            if mood_glucose_impact:
                correlations['mood_glucose'] = mood_glucose_impact
                
        # 4. Insulin Timing & Meal Spike
        if insulin_data and food_data:
            insulin_timing_impact = self._correlate_insulin_timing_and_meal_spike(glucose_data, insulin_data, food_data)
            if insulin_timing_impact:
                correlations['insulin_timing'] = insulin_timing_impact
        
        return correlations
        
    def _correlate_food_and_activity(self, glucose_data, food_data, activity_data):
        """Analyze how post-meal activity affects glucose"""
        correlations = {}
        
        for food_entry in food_data:
            meal_time = food_entry.timestamp
            
            # Find activities within 2 hours after a meal
            post_meal_activities = [
                activity for activity in activity_data
                if meal_time < activity.timestamp <= meal_time + timedelta(hours=2)
            ]
            
            for activity in post_meal_activities:
                # Get glucose readings after the activity
                post_activity_glucose = [
                    reading for reading in glucose_data
                    if activity.timestamp < reading.timestamp <= activity.timestamp + timedelta(hours=3)
                ]
                
                # Get comparable meals without activity
                similar_meals_without_activity = []
                for other_food in food_data:
                    if other_food.id == food_entry.id:
                        continue
                        
                    # Check if meal is similar (carbs within 20%)
                    if abs(other_food.carbs - food_entry.carbs) / food_entry.carbs <= 0.2:
                        # Check if no activity followed this meal
                        has_activity = any(
                            other_food.timestamp < act.timestamp <= other_food.timestamp + timedelta(hours=2)
                            for act in activity_data
                        )
                        
                        if not has_activity:
                            similar_meals_without_activity.append(other_food)
                
                # Get glucose after similar meals without activity
                post_inactive_meal_glucose = []
                for inactive_meal in similar_meals_without_activity:
                    readings = [
                        reading for reading in glucose_data
                        if inactive_meal.timestamp < reading.timestamp <= inactive_meal.timestamp + timedelta(hours=3)
                    ]
                    if readings:
                        post_inactive_meal_glucose.append(max(reading.value for reading in readings))
                
                # Calculate difference in peak glucose
                if post_activity_glucose and post_inactive_meal_glucose:
                    active_peak = max(reading.value for reading in post_activity_glucose)
                    inactive_peak_avg = sum(post_inactive_meal_glucose) / len(post_inactive_meal_glucose)
                    
                    correlations[f"meal_{food_entry.id}_activity_{activity.id}"] = {
                        'carbs': food_entry.carbs,
                        'activity_type': activity.activity_type,
                        'activity_intensity': activity.intensity,
                        'active_peak_glucose': active_peak,
                        'inactive_peak_glucose': inactive_peak_avg,
                        'glucose_reduction': inactive_peak_avg - active_peak,
                        'percent_reduction': (inactive_peak_avg - active_peak) / inactive_peak_avg * 100 if inactive_peak_avg > 0 else 0
                    }
        
        return correlations
        
    def _correlate_sleep_and_morning_glucose(self, glucose_data, sleep_data):
        """Analyze how sleep quality/duration affects morning glucose"""
        correlations = {}
        
        for sleep in sleep_data:
            if not sleep.end_time:
                continue
                
            # Get morning glucose (within 2 hours of waking)
            morning_glucose = [
                reading for reading in glucose_data
                if sleep.end_time < reading.timestamp <= sleep.end_time + timedelta(hours=2)
            ]
            
            if morning_glucose:
                morning_avg = np.mean([reading.value for reading in morning_glucose])
                
                correlations[f"sleep_{sleep.id}"] = {
                    'sleep_duration': sleep.duration_minutes / 60 if sleep.duration_minutes else 0,
                    'sleep_quality': sleep.quality,
                    'deep_sleep': sleep.deep_sleep_minutes,
                    'morning_glucose': morning_avg
                }
        
        # Group by sleep duration and quality
        if correlations:
            # By duration
            short_sleep = [data for data in correlations.values() if data['sleep_duration'] < 6]
            normal_sleep = [data for data in correlations.values() if 6 <= data['sleep_duration'] <= 8]
            long_sleep = [data for data in correlations.values() if data['sleep_duration'] > 8]
            
            # By quality (1-10 scale)
            poor_quality = [data for data in correlations.values() if data['sleep_quality'] and data['sleep_quality'] < 5]
            good_quality = [data for data in correlations.values() if data['sleep_quality'] and data['sleep_quality'] >= 5]
            
            overall = {
                'short_sleep_morning_avg': np.mean([data['morning_glucose'] for data in short_sleep]) if short_sleep else 0,
                'normal_sleep_morning_avg': np.mean([data['morning_glucose'] for data in normal_sleep]) if normal_sleep else 0,
                'long_sleep_morning_avg': np.mean([data['morning_glucose'] for data in long_sleep]) if long_sleep else 0,
                'poor_quality_morning_avg': np.mean([data['morning_glucose'] for data in poor_quality]) if poor_quality else 0,
                'good_quality_morning_avg': np.mean([data['morning_glucose'] for data in good_quality]) if good_quality else 0
            }
            
            correlations['overall'] = overall
        
        return correlations
        
    def _correlate_mood_and_glucose(self, glucose_data, mood_data):
        """Analyze how mood correlates with glucose levels"""
        correlations = {}
        
        for mood in mood_data:
            # Get glucose around mood log (2 hours before, 2 hours after)
            surrounding_glucose = [
                reading for reading in glucose_data
                if mood.timestamp - timedelta(hours=2) <= reading.timestamp <= mood.timestamp + timedelta(hours=2)
            ]
            
            if surrounding_glucose:
                values = [reading.value for reading in surrounding_glucose]
                
                correlations[f"mood_{mood.id}"] = {
                    'mood_rating': mood.rating,
                    'avg_glucose': np.mean(values),
                    'variability': np.std(values),
                    'in_range_percent': len([v for v in values if 70 <= v <= 180]) / len(values) * 100
                }
        
        # Group by mood rating
        if correlations:
            mood_ranges = {
                'low': [data for data in correlations.values() if data['mood_rating'] <= 3],
                'medium': [data for data in correlations.values() if 4 <= data['mood_rating'] <= 7],
                'high': [data for data in correlations.values() if data['mood_rating'] >= 8]
            }
            
            overall = {}
            for mood_range, data_list in mood_ranges.items():
                if data_list:
                    overall[f"{mood_range}_mood_avg_glucose"] = np.mean([data['avg_glucose'] for data in data_list])
                    overall[f"{mood_range}_mood_variability"] = np.mean([data['variability'] for data in data_list])
                    overall[f"{mood_range}_mood_in_range"] = np.mean([data['in_range_percent'] for data in data_list])
            
            correlations['overall'] = overall
        
        return correlations
        
    def _correlate_insulin_timing_and_meal_spike(self, glucose_data, insulin_data, food_data):
        """Analyze how insulin timing relative to meals affects post-meal spikes"""
        correlations = {}
        
        for food_entry in food_data:
            meal_time = food_entry.timestamp
            
            # Find insulin doses around this meal (1 hour before to 30 min after)
            meal_insulin = [
                insulin for insulin in insulin_data
                if meal_time - timedelta(hours=1) <= insulin.timestamp <= meal_time + timedelta(minutes=30)
            ]
            
            # Get post-meal glucose (3 hours)
            post_meal_glucose = [
                reading for reading in glucose_data
                if meal_time < reading.timestamp <= meal_time + timedelta(hours=3)
            ]
            
            if meal_insulin and post_meal_glucose:
                # Calculate timing between insulin and meal
                insulin_timing_minutes = min(
                    [(meal_time - insulin.timestamp).total_seconds() / 60 
                     for insulin in meal_insulin]
                )
                
                # Calculate post-meal spike
                pre_meal_glucose = None
                for reading in glucose_data:
                    if reading.timestamp <= meal_time:
                        pre_meal_glucose = reading.value
                        break
                
                if pre_meal_glucose:
                    post_meal_peak = max(reading.value for reading in post_meal_glucose)
                    spike_magnitude = post_meal_peak - pre_meal_glucose
                    
                    # Define prebolus categories
                    timing_category = "no_prebolus"
                    if insulin_timing_minutes > 0:  # Insulin before meal
                        if insulin_timing_minutes < 15:
                            timing_category = "short_prebolus"
                        elif insulin_timing_minutes < 30:
                            timing_category = "medium_prebolus"
                        else:
                            timing_category = "long_prebolus"
                    
                    correlations[f"meal_{food_entry.id}"] = {
                        'carbs': food_entry.carbs,
                        'insulin_timing_minutes': insulin_timing_minutes,
                        'timing_category': timing_category,
                        'pre_meal_glucose': pre_meal_glucose,
                        'post_meal_peak': post_meal_peak,
                        'spike_magnitude': spike_magnitude,
                        'spike_per_carb': spike_magnitude / food_entry.carbs if food_entry.carbs > 0 else 0
                    }
        
        # Group by timing category
        if correlations:
            timing_groups = {}
            for data in correlations.values():
                category = data['timing_category']
                if category not in timing_groups:
                    timing_groups[category] = []
                timing_groups[category].append(data)
            
            timing_impacts = {}
            for category, data_list in timing_groups.items():
                if data_list:
                    timing_impacts[category] = {
                        'avg_spike': np.mean([data['spike_magnitude'] for data in data_list]),
                        'avg_spike_per_carb': np.mean([data['spike_per_carb'] for data in data_list]),
                        'count': len(data_list)
                    }
            
            correlations['timing_impacts'] = timing_impacts
        
        return correlations
    
    def _analyze_glucose_patterns(self, glucose_data: List[GlucoseReading]) -> Dict[str, Any]:
        """Analyze glucose level patterns"""
        if not glucose_data:
            return {}
        
        values = [reading.value for reading in glucose_data]
        
        return {
            'average': np.mean(values),
            'std_dev': np.std(values),
            'time_in_range': len([v for v in values if 70 <= v <= 180]) / len(values) * 100,
            'frequent_highs': len([v for v in values if v > 250]) / len(values) * 100,
            'frequent_lows': len([v for v in values if v < 70]) / len(values) * 100,
            'dawn_phenomenon': self._check_dawn_phenomenon(glucose_data)
        }
    
    def _analyze_meal_patterns(self, glucose_data: List[GlucoseReading], food_data: List[Food]) -> Dict[str, Any]:
        """Analyze meal-related glucose patterns"""
        patterns = {}
        
        for food_entry in food_data:
            meal_time = food_entry.timestamp
            
            # Get glucose readings 1-3 hours after meal
            post_meal_readings = [
                reading for reading in glucose_data
                if meal_time < reading.timestamp <= meal_time + timedelta(hours=3)
            ]
            
            if post_meal_readings:
                peak_glucose = max(reading.value for reading in post_meal_readings)
                patterns[f"meal_{food_entry.id}"] = {
                    'carbs': food_entry.total_carbs,
                    'peak_glucose': peak_glucose,
                    'meal_type': food_entry.meal_type,
                    'spike_magnitude': peak_glucose - glucose_data[0].value if glucose_data else 0
                }
        
        return patterns
    
    def _analyze_insulin_patterns(self, glucose_data: List[GlucoseReading], insulin_data: List[Insulin]) -> Dict[str, Any]:
        """Analyze insulin effectiveness patterns"""
        patterns = {}
        
        for insulin_dose in insulin_data:
            dose_time = insulin_dose.timestamp
            
            # Get glucose readings 2-4 hours after insulin
            post_insulin_readings = [
                reading for reading in glucose_data
                if dose_time < reading.timestamp <= dose_time + timedelta(hours=4)
            ]
            
            if post_insulin_readings:
                glucose_drop = glucose_data[0].value - min(reading.value for reading in post_insulin_readings)
                patterns[f"insulin_{insulin_dose.id}"] = {
                    'units': insulin_dose.units,
                    'type': insulin_dose.insulin_type,
                    'glucose_drop': glucose_drop,
                    'effectiveness': glucose_drop / insulin_dose.units if insulin_dose.units > 0 else 0
                }
        
        return patterns
    
    def _analyze_time_patterns(self, glucose_data: List[GlucoseReading]) -> Dict[str, Any]:
        """Analyze time-of-day patterns"""
        hourly_averages = {}
        
        for reading in glucose_data:
            hour = reading.timestamp.hour
            if hour not in hourly_averages:
                hourly_averages[hour] = []
            hourly_averages[hour].append(reading.value)
        
        # Calculate averages for each hour
        hourly_patterns = {
            hour: {
                'average': np.mean(values),
                'count': len(values)
            }
            for hour, values in hourly_averages.items()
        }
        
        return hourly_patterns
    
    def _analyze_variability(self, glucose_data: List[GlucoseReading]) -> Dict[str, Any]:
        """Analyze glucose variability"""
        if len(glucose_data) < 2:
            return {}
        
        values = [reading.value for reading in glucose_data]
        
        return {
            'coefficient_of_variation': (np.std(values) / np.mean(values)) * 100,
            'mean_absolute_glucose_change': np.mean(np.abs(np.diff(values))),
            'glucose_variability_percentage': (np.std(values) / np.mean(values)) * 100
        }
    
    def _check_dawn_phenomenon(self, glucose_data: List[GlucoseReading]) -> bool:
        """Check for dawn phenomenon (early morning glucose rise)"""
        morning_readings = [
            reading for reading in glucose_data
            if 4 <= reading.timestamp.hour <= 8
        ]
        
        if len(morning_readings) < 3:
            return False
        
        # Check if glucose tends to rise in early morning hours
        morning_values = [reading.value for reading in morning_readings]
        return np.mean(morning_values) > 140  # Simple heuristic
    
    def _create_comprehensive_context(
        self,
        user: User,
        patterns: Dict[str, Any],
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        activity_data: List[Activity],
        sleep_data: List[Sleep],
        mood_data: List[Mood],
        medication_data: List[Medication],
        illness_data: List[Illness],
        menstrual_cycle_data: List[MenstrualCycle],
        health_data: List[HealthData]
    ) -> str:
        """Create comprehensive context string for AI model using all data streams"""
        
        # Handle missing date_of_birth gracefully
        if hasattr(user, "birthdate") and user.birthdate:
            age = (datetime.now() - user.birthdate).days // 365
        elif hasattr(user, "date_of_birth") and user.date_of_birth:
            age = (datetime.now() - user.date_of_birth).days // 365
        else:
            age = 'Unknown'
            
        # Calculate time periods for different analyses
        now = datetime.utcnow()
        past_24h = now - timedelta(hours=24)
        past_week = now - timedelta(days=7)
        
        # Get recent data
        recent_glucose = [g for g in glucose_data if g.timestamp >= past_24h]
        recent_insulin = [i for i in insulin_data if i.timestamp >= past_24h]
        recent_food = [f for f in food_data if f.timestamp >= past_24h]
        recent_activity = [a for a in activity_data if a.timestamp >= past_24h]
        recent_sleep = [s for s in sleep_data if s.start_time >= past_week]
        recent_mood = [m for m in mood_data if m.timestamp >= past_week]
        
        # Active illnesses
        active_illnesses = [
            i for i in illness_data 
            if not i.end_date or i.end_date >= past_week
        ]
        
        # Medication adherence
        scheduled_meds = len(medication_data)
        taken_meds = len([m for m in medication_data if m.taken])
        med_adherence = taken_meds / scheduled_meds * 100 if scheduled_meds > 0 else 0
        
        # Current menstrual cycle phase (if relevant)
        current_cycle = None
        if menstrual_cycle_data:
            current_cycle = menstrual_cycle_data[-1]
        
        # Check for correlation insights
        correlation_insights = []
        
        # Food & activity correlations
        if 'correlations' in patterns and 'food_activity' in patterns['correlations']:
            food_activity = patterns['correlations']['food_activity']
            for key, data in food_activity.items():
                if 'percent_reduction' in data and data['percent_reduction'] > 15:
                    correlation_insights.append(
                        f"Post-meal {data['activity_type']} reduced glucose spike by {data['percent_reduction']:.1f}%"
                    )
        
        # Sleep correlations
        if 'correlations' in patterns and 'sleep_morning_glucose' in patterns['correlations']:
            sleep_data = patterns['correlations']['sleep_morning_glucose'].get('overall', {})
            if sleep_data:
                # Compare short vs normal sleep
                if sleep_data.get('short_sleep_morning_avg') and sleep_data.get('normal_sleep_morning_avg'):
                    diff = sleep_data['short_sleep_morning_avg'] - sleep_data['normal_sleep_morning_avg']
                    if abs(diff) > 15:
                        direction = "increased" if diff > 0 else "decreased"
                        correlation_insights.append(
                            f"Short sleep (<6h) {direction} morning glucose by {abs(diff):.1f} mg/dL compared to normal sleep"
                        )
                
                # Compare sleep quality
                if sleep_data.get('poor_quality_morning_avg') and sleep_data.get('good_quality_morning_avg'):
                    diff = sleep_data['poor_quality_morning_avg'] - sleep_data['good_quality_morning_avg']
                    if abs(diff) > 15:
                        correlation_insights.append(
                            f"Poor sleep quality increased morning glucose by {abs(diff):.1f} mg/dL"
                        )
        
        # Mood correlations
        if 'correlations' in patterns and 'mood_glucose' in patterns['correlations']:
            mood_data = patterns['correlations']['mood_glucose'].get('overall', {})
            if mood_data:
                if mood_data.get('low_mood_variability') and mood_data.get('high_mood_variability'):
                    diff = mood_data['low_mood_variability'] - mood_data['high_mood_variability']
                    if abs(diff) > 10:
                        correlation_insights.append(
                            f"Lower mood ratings correlate with {abs(diff):.1f}% higher glucose variability"
                        )
        
        # Insulin timing correlations
        if 'correlations' in patterns and 'insulin_timing' in patterns['correlations']:
            timing_impacts = patterns['correlations']['insulin_timing'].get('timing_impacts', {})
            if timing_impacts and 'long_prebolus' in timing_impacts and 'no_prebolus' in timing_impacts:
                prebolus_impact = timing_impacts['long_prebolus']['avg_spike'] - timing_impacts['no_prebolus']['avg_spike']
                if prebolus_impact < -15:  # Negative means lower spike with prebolus
                    correlation_insights.append(
                        f"Pre-bolusing insulin 30+ minutes before meals reduced post-meal spikes by {abs(prebolus_impact):.1f} mg/dL"
                    )
        
        # Build the comprehensive context
        context = f"""
Patient Profile:
- Age: {age}
- Gender: {getattr(user, 'gender', 'Unknown')}
- Diabetes Type: {getattr(user, 'diabetes_type', 'Unknown')}
- Target Range: {getattr(user, 'target_glucose_min', 70)}-{getattr(user, 'target_glucose_max', 180)} mg/dL
- Insulin-to-Carb Ratio: 1:{getattr(user, 'insulin_carb_ratio', 'Unknown')}
- Correction Factor: {getattr(user, 'insulin_sensitivity_factor', 'Unknown')}

Current Glucose Patterns (24-hour analysis):
- Average Glucose: {patterns['glucose_patterns'].get('average', 'Unknown'):.1f} mg/dL
- Time in Range: {patterns['glucose_patterns'].get('time_in_range', 0):.1f}%
- Glucose Variability: {patterns['variability'].get('coefficient_of_variation', 0):.1f}%
- Frequent highs (>250): {patterns['glucose_patterns'].get('frequent_highs', 0):.1f}%
- Frequent lows (<70): {patterns['glucose_patterns'].get('frequent_lows', 0):.1f}%

Recent Data Summary:
- Glucose readings: {len(recent_glucose)} in last 24 hours
- Insulin doses: {len(recent_insulin)} in last 24 hours
- Meals logged: {len(recent_food)} in last 24 hours
- Activity sessions: {len(recent_activity)} in last 24 hours
- Sleep logs: {len(recent_sleep)} in last week
- Mood logs: {len(recent_mood)} in last week
- Medication adherence: {med_adherence:.1f}%
- Active illnesses: {len(active_illnesses)}
"""

        # Add activity insights if available
        if 'activity_patterns' in patterns and patterns['activity_patterns']:
            activity_impacts = patterns['activity_patterns'].get('activity_impacts', {})
            context += "\nActivity Impact on Glucose:\n"
            
            for activity_type, impact in activity_impacts.items():
                context += f"- {activity_type}: Avg glucose drop of {impact['avg_glucose_drop']:.1f} mg/dL ({impact['count']} sessions)\n"
        
        # Add sleep insights if available
        if 'sleep_patterns' in patterns and patterns['sleep_patterns']:
            sleep_impacts = patterns['sleep_patterns'].get('sleep_impacts', {})
            if sleep_impacts:
                context += "\nSleep Impact on Glucose:\n"
                context += f"- Short sleep (<6h) avg glucose: {sleep_impacts.get('short_sleep_avg_glucose', 0):.1f} mg/dL\n"
                context += f"- Normal sleep (6-8h) avg glucose: {sleep_impacts.get('normal_sleep_avg_glucose', 0):.1f} mg/dL\n"
                context += f"- Dawn phenomenon frequency: {sleep_impacts.get('dawn_phenomenon_frequency', 0) * 100:.1f}%\n"
        
        # Add mood insights if available
        if 'mood_patterns' in patterns and patterns['mood_patterns']:
            mood_impacts = patterns['mood_patterns'].get('mood_impacts', {})
            if mood_impacts and len(mood_impacts) > 1:
                context += "\nMood Impact on Glucose:\n"
                for rating, impact in mood_impacts.items():
                    if rating.isdigit():
                        context += f"- Mood rating {rating}: Avg glucose {impact['avg_glucose']:.1f} mg/dL ({impact['count']} logs)\n"
        
        # Add illness insights if available
        if 'illness_patterns' in patterns and patterns['illness_patterns']:
            active_illness_data = [data for key, data in patterns['illness_patterns'].items() if key.startswith('illness_')]
            if active_illness_data:
                context += "\nIllness Impact on Glucose:\n"
                for illness in active_illness_data[:3]:  # Show up to 3 illnesses
                    context += f"- {illness['name']}: Glucose increase of {illness['glucose_increase']:.1f} mg/dL (severity: {illness['severity']})\n"
        
        # Add menstrual cycle insights if available
        if 'menstrual_patterns' in patterns and patterns['menstrual_patterns'] and current_cycle:
            context += "\nMenstrual Cycle Impact:\n"
            cycle_data = patterns['menstrual_patterns'].get(f"cycle_{current_cycle.id}", {})
            if cycle_data:
                context += f"- Period glucose: {cycle_data.get('period_avg_glucose', 0):.1f} mg/dL\n"
                context += f"- Luteal phase glucose: {cycle_data.get('luteal_avg_glucose', 0):.1f} mg/dL\n"
                if 'glucose_change' in cycle_data:
                    direction = "increased" if cycle_data['glucose_change'] > 0 else "decreased"
                    context += f"- Glucose {direction} by {abs(cycle_data['glucose_change']):.1f} mg/dL in luteal phase\n"
        
        # Add correlation insights
        if correlation_insights:
            context += "\nKey Correlations Detected:\n"
            for insight in correlation_insights[:5]:  # Show up to 5 correlations
                context += f"- {insight}\n"
        
        # Daily patterns section
        context += f"""
Daily Patterns:
- Morning (6am-12pm) avg glucose: {self._calculate_time_range_average(recent_glucose, 6, 12):.1f} mg/dL
- Afternoon (12pm-6pm) avg glucose: {self._calculate_time_range_average(recent_glucose, 12, 18):.1f} mg/dL  
- Evening (6pm-12am) avg glucose: {self._calculate_time_range_average(recent_glucose, 18, 24):.1f} mg/dL
- Overnight (12am-6am) avg glucose: {self._calculate_time_range_average(recent_glucose, 0, 6):.1f} mg/dL

Based on this comprehensive analysis of multiple data streams, please provide 5 specific, actionable recommendations 
to improve glucose management. For each recommendation:
1. Provide a clear, concise title (one short sentence)
2. Include detailed explanation with specific actions (2-3 sentences)
3. Categorize as: insulin, nutrition, activity, timing, monitoring, sleep, stress, or general
4. Indicate priority as: high, medium, or low
5. Suggest a specific action the user can take (e.g., "Try taking insulin 20 minutes before your next meal")
6. If possible, suggest a specific time when this action should be taken
"""
        return context
        
    def _calculate_time_range_average(self, glucose_data: List[GlucoseReading], start_hour: int, end_hour: int) -> float:
        """Calculate average glucose for a specific time range within a day"""
        if not glucose_data:
            return 0
            
        time_range_readings = [
            reading.value for reading in glucose_data
            if start_hour <= reading.timestamp.hour < end_hour
        ]
        
        if not time_range_readings:
            return 0
            
        return sum(time_range_readings) / len(time_range_readings)
    
    async def _generate_ai_recommendations(self, context: str) -> str:
        """Generate recommendations using AI model or Inference API"""
        prompt = f"{context}\n\nRecommendations:"
        json_instructions = (
            "Please provide exactly 5 personalized, actionable recommendations as a JSON array. "
            "Each item must have: title (string), description (string), category (one of ['insulin','nutrition','activity','timing','monitoring','sleep','stress','general']), "
            "priority ('high'|'medium'|'low'), action (string), and timing (string or null). "
            "Respond ONLY with a valid JSON array, no extra text."
        )
        try:
            if settings.MODEL_NAME == "openai/gpt-oss-20b":
                import os
                from openai import OpenAI
                enhanced_prompt = f"{prompt}\n\n{json_instructions}"
                try:
                    client = OpenAI(
                        base_url="https://router.huggingface.co/v1",
                        api_key=os.environ["HF_TOKEN"],
                    )
                    messages = [
                        {"role": "system", "content": "You are a diabetes management assistant that provides personalized, evidence-based recommendations. Be specific, actionable, and concise. Focus on the user's unique patterns and data. Output only valid JSON."},
                        {"role": "user", "content": enhanced_prompt}
                    ]
                    completion = client.chat.completions.create(
                        model="openai/gpt-oss-20b:fireworks-ai",
                        messages=messages,
                        temperature=0.7,
                        max_tokens=1024,
                    )
                    if completion.choices:
                        logger.info("Successfully generated AI recommendations")
                        return completion.choices[0].message.content.strip()
                    else:
                        logger.warning("No choices returned from model API")
                        return self._fallback_recommendations()
                except Exception as e:
                    logger.error(f"Error with Fireworks API: {str(e)}")
                    return self._fallback_recommendations()
            else:
                # Use local/transformers pipeline
                response = self.generator(
                    f"{prompt}\n\n{json_instructions}",
                    max_new_tokens=512,
                    temperature=0.7,
                    do_sample=True,
                    pad_token_id=self.generator.tokenizer.eos_token_id
                )
                if isinstance(response, list) and len(response) > 0:
                    generated_text = response[0]['generated_text']
                    return generated_text.strip()
                return response if isinstance(response, str) else ""
        except Exception as e:
            logger.error(f"Error generating AI recommendations: {str(e)}")
            return self._fallback_recommendations()
    
    def _fallback_recommendations(self) -> str:
        """Provide fallback recommendations when AI generation fails"""
        return """
1. Monitor post-meal glucose trends to identify patterns
Title: Track glucose patterns after meals
Category: monitoring
Priority: medium

2. Adjust insulin timing based on food composition
Title: Consider pre-bolusing insulin before high-carb meals
Category: insulin
Priority: medium

3. Be consistent with meal carbohydrate content
Title: Maintain consistent carbohydrate intake between meals
Category: nutrition
Priority: low

4. Review insulin correction factors with healthcare provider
Title: Review insulin sensitivity factors for more accurate corrections
Category: insulin
Priority: low

5. Balance physical activity with appropriate glucose management
Title: Balance exercise with reduced insulin or added carbs
Category: exercise
Priority: medium
"""
    
    def _process_recommendations(self, ai_text: str, user_id: int) -> List[Dict[str, Any]]:
        """Process AI-generated text into structured recommendations, prefer JSON if possible. Attach example events and graph data for drill-down."""
        import json, re
        recommendations = []
        # Try JSON parsing first
        try:
            logger.info(f"Raw AI output: {ai_text}")
            parsed = json.loads(ai_text)
            if isinstance(parsed, list) and all(isinstance(item, dict) for item in parsed):
                for item in parsed:
                    rec = {
                        'title': item.get('title', ''),
                        'description': item.get('description', ''),
                        'category': item.get('category', 'general'),
                        'priority': item.get('priority', 'medium'),
                        'confidence': 0.8,
                        'action': item.get('action', ''),
                        'timing': item.get('timing', ''),
                        'context': self._attach_examples_and_graph(item)
                    }
                    recommendations.append(rec)
                logger.info(f"Processed {len(recommendations)} recommendations from JSON output: {recommendations}")
                return recommendations[:5]
        except Exception as e:
            logger.warning(f"AI output was not valid JSON, falling back to text parsing: {e}")

        # Robustly extract multiple recommendations from markdown, numbered, or mixed text
        # Split on numbered points (e.g., 1. Title: ... or 1) Title: ...)
        numbered_items = re.split(r'\n(?=\d+[\.)] )', ai_text.strip())
        if len(numbered_items) > 1:
            for item in numbered_items:
                item = item.strip()
                if not item:
                    continue
                # Try to extract fields from each item
                title = re.search(r'Title:?\s*(.*)', item, re.IGNORECASE)
                description = re.search(r'Description:?\s*([\s\S]*?)(?:\nCategory:|\nPriority:|\nAction:|\nTiming:|$)', item, re.IGNORECASE)
                category = re.search(r'Category:?\s*(.*)', item, re.IGNORECASE)
                priority = re.search(r'Priority:?\s*(.*)', item, re.IGNORECASE)
                action = re.search(r'Action:?\s*(.*)', item, re.IGNORECASE)
                timing = re.search(r'Timing:?\s*(.*)', item, re.IGNORECASE)
                rec = {
                    'title': title.group(1).strip() if title else '',
                    'description': description.group(1).strip() if description else '',
                    'category': category.group(1).strip().lower() if category else 'general',
                    'priority': priority.group(1).strip().lower() if priority else 'medium',
                    'confidence': 0.8,
                    'action': action.group(1).strip() if action else '',
                    'timing': timing.group(1).strip() if timing else '',
                    'context': self._attach_examples_and_graph({
                        'title': title.group(1).strip() if title else '',
                        'description': description.group(1).strip() if description else '',
                        'category': category.group(1).strip().lower() if category else 'general',
                    })
                }
                if rec['title'] or rec['description']:
                    recommendations.append(rec)
            if recommendations:
                logger.info(f"Processed {len(recommendations)} recommendations from numbered text content")
                return recommendations[:5]

        # Fallback: try to split on markdown-style (--- or **1. Title:**)
        items = re.split(r'\n---+\n|(?=\*\*\d+\. Title:)', ai_text)
        for item in items:
            if not item.strip():
                continue
            title = re.search(r'\*\*\d+\. Title:\*\*\s*(.*)', item)
            description = re.search(r'\*\*Description:\*\*\s*([\s\S]*?)\n\*\*Category:', item)
            category = re.search(r'\*\*Category:\*\*\s*(.*)', item)
            priority = re.search(r'\*\*Priority:\*\*\s*(.*)', item)
            action = re.search(r'\*\*Action:\*\*\s*(.*)', item)
            timing = re.search(r'\*\*Timing:\*\*\s*(.*)', item)
            rec = {
                'title': title.group(1).strip() if title else '',
                'description': description.group(1).strip() if description else '',
                'category': category.group(1).strip().lower() if category else 'general',
                'priority': priority.group(1).strip().lower() if priority else 'medium',
                'confidence': 0.8,
                'action': action.group(1).strip() if action else '',
                'timing': timing.group(1).strip() if timing else '',
                'context': self._attach_examples_and_graph({
                    'title': title.group(1).strip() if title else '',
                    'description': description.group(1).strip() if description else '',
                    'category': category.group(1).strip().lower() if category else 'general',
                })
            }
            if rec['title'] or rec['description']:
                recommendations.append(rec)
        if recommendations:
            logger.info(f"Processed {len(recommendations)} recommendations from markdown-style content")
            return recommendations[:5]

        # Fallback: original text parsing logic (numbered points)
        lines = ai_text.strip().split('\n')
        current_rec = ""
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line[0].isdigit() and ('.' in line[:5] or ')' in line[:5]):
                if current_rec:
                    rec_data = self._parse_recommendation(current_rec, user_id)
                    if rec_data:
                        rec_data['context'] = self._attach_examples_and_graph(rec_data)
                        recommendations.append(rec_data)
                current_rec = line
            else:
                current_rec += "\n" + line
        if current_rec:
            rec_data = self._parse_recommendation(current_rec, user_id)
            if rec_data:
                rec_data['context'] = self._attach_examples_and_graph(rec_data)
                recommendations.append(rec_data)
        if not recommendations:
            logger.warning("Failed to parse recommendations from AI output, using fallback")
            fallback_text = self._fallback_recommendations()
            return self._process_recommendations(fallback_text, user_id)
        logger.info(f"Successfully processed {len(recommendations)} recommendations (text fallback)")
        return recommendations[:5]

    def _attach_examples_and_graph(self, rec: dict) -> dict:
        """Attach example events and graph data to the recommendation context for drill-down UI."""
        # This is a stub. In production, this would use the analyzed patterns and user data to find relevant events.
        # For now, we simulate with a placeholder example and graph data.
        import random
        now = datetime.utcnow()
        # Example event: a glucose spike, meal, or insulin event
        example_event = {
            'timestamp': (now - timedelta(hours=random.randint(1, 24))).isoformat(),
            'value': random.randint(60, 300),
            'event_type': rec.get('category', 'general'),
            'note': f"Example event for {rec.get('category', 'general')}"
        }
        # Graph data: a list of (timestamp, value) pairs for the last 12 hours
        graph_data = [
            {
                'timestamp': (now - timedelta(hours=12) + timedelta(minutes=15*i)).isoformat(),
                'value': 100 + 40 * random.sin(i/4.0) + random.randint(-10, 10)
            }
            for i in range(48)
        ]
        context = rec.get('context', {}) if 'context' in rec else {}
        context.update({
            'generated_at': now.isoformat(),
            'ai_model': getattr(self, 'model_name', 'unknown'),
            'example_event': example_event,
            'graph_data': graph_data
        })
        return context
    
    def _parse_recommendation(self, rec_text: str, user_id: int) -> Optional[Dict[str, Any]]:
        """Parse a single recommendation text into structured data"""
        if not rec_text or len(rec_text.strip()) < 10:
            return None
        
        # Remove numbering
        text = rec_text
        if text[0].isdigit():
            text = text[text.find('.') + 1:].strip() if '.' in text else text[1:].strip()
        
        lines = text.split('\n')
        result = {
            'description': text,
            'title': '',
            'category': 'general',
            'priority': 'medium',
            'confidence': 0.8,
            'action': '',
            'context': {
                'generated_at': datetime.utcnow().isoformat(),
                'ai_model': self.model_name
            }
        }
        
        # Try to extract structured information
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Look for labeled fields
            if line.lower().startswith('title:'):
                result['title'] = line[len('title:'):].strip()
            elif line.lower().startswith('category:'):
                category = line[len('category:'):].strip().lower()
                # Normalize category values
                if category in ['insulin', 'nutrition', 'activity', 'monitoring', 'sleep', 'stress', 'general']:
                    result['category'] = category
                else:
                    result['category'] = self._categorize_recommendation(category)
            elif line.lower().startswith('priority:'):
                priority = line[len('priority:'):].strip().lower()
                if priority in ['high', 'medium', 'low']:
                    result['priority'] = priority
                else:
                    result['priority'] = self._prioritize_recommendation(priority)
            elif line.lower().startswith('action:'):
                result['action'] = line[len('action:'):].strip()
            elif line.lower().startswith('timing:'):
                result['timing'] = line[len('timing:'):].strip()
        
        # If no explicit title was found, extract it from the first line
        if not result['title'] and lines:
            result['title'] = lines[0].split('.')[0][:60] + ('...' if len(lines[0].split('.')[0]) > 60 else '')
        
        # If we couldn't extract much structure, fall back to our categorical methods
        if result['category'] == 'general' and not any(k in result for k in ['action', 'timing']):
            result['category'] = self._categorize_recommendation(text)
            result['priority'] = self._prioritize_recommendation(text)
            
        logger.debug(f"Parsed recommendation: {result['title']}")
        return result
    
    def _categorize_recommendation(self, text: str) -> str:
        """Categorize recommendation based on content"""
        text_lower = text.lower()
        
        if any(word in text_lower for word in ['insulin', 'dose', 'bolus', 'correction']):
            return 'insulin'
        elif any(word in text_lower for word in ['meal', 'food', 'carb', 'eat']):
            return 'nutrition'
        elif any(word in text_lower for word in ['exercise', 'activity', 'walk']):
            return 'exercise'
        elif any(word in text_lower for word in ['timing', 'time', 'schedule']):
            return 'timing'
        elif any(word in text_lower for word in ['monitor', 'check', 'test']):
            return 'monitoring'
        else:
            return 'general'
    
    def _prioritize_recommendation(self, text: str) -> str:
        """Determine recommendation priority"""
        text_lower = text.lower()
        
        # High priority keywords
        if any(word in text_lower for word in ['urgent', 'immediate', 'dangerous', 'severe']):
            return 'high'
        # Medium priority keywords
        elif any(word in text_lower for word in ['important', 'significant', 'consider']):
            return 'medium'
        else:
            return 'low'
    
    def _recommendation_to_dict(self, recommendation: Recommendation) -> Dict[str, Any]:
        """Convert recommendation model to dictionary"""
        return {
            'id': recommendation.id,
            'title': recommendation.title,
            'description': recommendation.description,
            'category': recommendation.category,
            'priority': recommendation.priority,
            'confidence_score': recommendation.confidence_score,
            'created_at': recommendation.created_at.isoformat(),
            'context': json.loads(recommendation.context_data) if recommendation.context_data else {}
        }
