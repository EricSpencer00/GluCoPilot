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
import random
import math

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
    def __init__(self):
        """Initialize the AI insights engine with models if local generation is needed."""
        self.model_name = "openai/gpt-oss-20b"  # Default model name
        # Load local model if needed (when not using remote APIs)
        if not settings.USE_REMOTE_MODEL:
            try:
                logger.info("Initializing local models for insights generation...")
                self.tokenizer = AutoTokenizer.from_pretrained(
                    settings.MODEL_PATH or "DialoGPT-medium",
                    local_files_only=True
                )
                self.model = AutoModelForCausalLM.from_pretrained(
                    settings.MODEL_PATH or "DialoGPT-medium",
                    local_files_only=True
                )
                self.generator = pipeline(
                    "text-generation",
                    model=self.model,
                    tokenizer=self.tokenizer,
                    pad_token_id=self.tokenizer.eos_token_id
                )
                # Initialize sentence transformer for semantic search
                self.sentence_model = SentenceTransformer(
                    settings.SENTENCE_TRANSFORMER_PATH or "sentence-transformer",
                    device="cpu"
                )
                logger.info("Models loaded successfully")
            except Exception as e:
                logger.error(f"Error loading models: {str(e)}")
                self.generator = None
                self.sentence_model = None
    
    async def generate_recommendations(
        self,
        user: User,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        db: Session,
        activity_data=None,
        sleep_data=None,
        mood_data=None,
        medication_data=None,
        illness_data=None,
        menstrual_cycle_data=None,
        health_data=None
    ) -> List[Dict[str, Any]]:
        """Generate AI recommendations based on user data and patterns."""
        logger.info(f"Generating recommendations for user {user.id}")
        try:
            # Default empty lists for optional params
            activity_data = activity_data or []
            sleep_data = sleep_data or []
            mood_data = mood_data or []
            medication_data = medication_data or []
            illness_data = illness_data or []
            menstrual_cycle_data = menstrual_cycle_data or []
            health_data = health_data or []
            
            # Analyze patterns in all data streams
            patterns = await self._analyze_all_patterns(
                glucose_data, insulin_data, food_data, 
                activity_data, sleep_data, mood_data,
                medication_data, illness_data, menstrual_cycle_data, health_data
            )
            
            # Create comprehensive context with all analyzed patterns
            context = self._create_comprehensive_context(
                user, patterns, glucose_data, insulin_data, food_data,
                activity_data, sleep_data, mood_data, medication_data,
                illness_data, menstrual_cycle_data, health_data
            )
            
            # Generate AI recommendations
            ai_text = await self._generate_ai_recommendations(context)
            
            # Process into structured format
            recommendations = self._process_recommendations(ai_text, user.id)
            
            # Determine suggested implementation times
            now = datetime.utcnow()
            for rec in recommendations:
                # If timing not provided by AI, calculate a reasonable time
                if not rec.get('timing'):
                    rec['timing'] = self._calculate_suggested_time(rec, now).isoformat()
            
            return recommendations
            
        except Exception as e:
            logger.error(f"Error generating recommendations: {str(e)}")
            return [{
                'title': "Error generating recommendations",
                'description': "An error occurred while analyzing your data. Please try again later.",
                'category': 'general',
                'priority': 'medium',
                'confidence': 0.5,
                'action': "Try again later or contact support if the problem persists.",
                'timing': (datetime.utcnow() + timedelta(hours=1)).isoformat()
            }]

    def _find_meal_insulin_spike_events(self, glucose_data, insulin_data, food_data):
        """Find meal+insulin+glucose spike patterns in the last 24h."""
        if not glucose_data or not insulin_data or not food_data:
            return []
        events = []
        for food in food_data:
            meal_time = food.timestamp
            # Find insulin within 1h before to 15m after meal
            relevant_insulin = [i for i in insulin_data if meal_time - timedelta(hours=1) <= i.timestamp <= meal_time + timedelta(minutes=15)]
            if not relevant_insulin:
                continue
            insulin = min(relevant_insulin, key=lambda i: abs((i.timestamp - meal_time).total_seconds()))
            # Glucose before meal
            pre_meal = [g for g in glucose_data if meal_time - timedelta(minutes=30) <= g.timestamp <= meal_time]
            pre_val = pre_meal[-1].value if pre_meal else None
            # Glucose 1-3h after meal
            post_meal = [g for g in glucose_data if meal_time < g.timestamp <= meal_time + timedelta(hours=3)]
            if not post_meal or pre_val is None:
                continue
            peak = max(post_meal, key=lambda g: g.value)
            spike = peak.value - pre_val
            # Only consider significant spikes
            if spike > 40 and food.total_carbs >= 20:
                events.append({
                    'meal_time': meal_time,
                    'carbs': food.total_carbs,
                    'insulin': insulin.units,
                    'insulin_time': insulin.timestamp,
                    'pre_glucose': pre_val,
                    'peak_glucose': peak.value,
                    'peak_time': peak.timestamp,
                    'spike': spike
                })
            
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
        """Build a comprehensive context string for AI recommendations."""
        # Calculate age if possible
        age = getattr(user, 'age', 'Unknown')
        # Recent data for summary
        now = datetime.utcnow()
        recent_glucose = [g for g in glucose_data if g.timestamp >= now - timedelta(hours=24)]
        recent_insulin = [i for i in insulin_data if i.timestamp >= now - timedelta(hours=24)]
        recent_food = [f for f in food_data if f.timestamp >= now - timedelta(hours=24)]
        recent_activity = [a for a in activity_data if a.timestamp >= now - timedelta(hours=24)]
        recent_sleep = [s for s in sleep_data if s.start_time >= now - timedelta(days=7)]
        recent_mood = [m for m in mood_data if m.timestamp >= now - timedelta(days=7)]

        # Find and summarize meal-insulin-glucose spike events
        spike_events = self._find_meal_insulin_spike_events(glucose_data, insulin_data, food_data)
        spike_summaries = ""
        if spike_events:
            spike_summaries += "\nRecent meal-insulin-glucose spike events detected:\n"
            for e in spike_events:
                spike_summaries += (
                    f"- At {e['meal_time'].strftime('%Y-%m-%d %H:%M')}, user took {e['insulin']}u insulin at {e['insulin_time'].strftime('%H:%M')}, "
                    f"ate {e['carbs']}g carbs, glucose rose from {e['pre_glucose']} to {e['peak_glucose']} mg/dL in 3h (spike: {e['spike']} mg/dL).\n"
                )
            spike_summaries += "For each event, suggest a more optimal insulin:carb ratio or action to prevent the spike.\n"

        def _fmt(val):
            return f"{val:.1f}" if isinstance(val, (int, float)) else str(val)

        context = f"""
            Patient Profile:
            - Age: {age}
            - Gender: {getattr(user, 'gender', 'Unknown')}
            - Diabetes Type: {getattr(user, 'diabetes_type', 'Unknown')}
            - Target Range: {getattr(user, 'target_glucose_min', 70)}-{getattr(user, 'target_glucose_max', 180)} mg/dL
            - Insulin-to-Carb Ratio: 1:{getattr(user, 'insulin_carb_ratio', 'Unknown')}
            - Correction Factor: {getattr(user, 'insulin_sensitivity_factor', 'Unknown')}
            {spike_summaries}

            Current Glucose Patterns (24-hour analysis):
            - Average Glucose: {_fmt(patterns['glucose_patterns'].get('average', 'Unknown'))} mg/dL
            - Time in Range: {_fmt(patterns['glucose_patterns'].get('time_in_range', 'Unknown'))}%
            - Glucose Variability: {_fmt(patterns['variability'].get('coefficient_of_variation', 'Unknown'))}%
            - Frequent highs (>250): {_fmt(patterns['glucose_patterns'].get('frequent_highs', 'Unknown'))}%
            - Frequent lows (<70): {_fmt(patterns['glucose_patterns'].get('frequent_lows', 'Unknown'))}%

            Recent Data Summary:
            - Glucose readings: {len(recent_glucose)} in last 24 hours
            - Insulin doses: {len(recent_insulin)} in last 24 hours
            - Meals logged: {len(recent_food)} in last 24 hours
            - Activity sessions: {len(recent_activity)} in last 24 hours
            - Sleep logs: {len(recent_sleep)} in last week
            - Mood logs: {len(recent_mood)} in last week

            Based on this comprehensive analysis of multiple data streams, please provide 5 specific, actionable recommendations
            to improve glucose management. For each recommendation:
            1. Provide a clear, concise title (one short sentence)
            2. Include detailed explanation with specific actions (2-3 sentences)
            3. Categorize as: insulin, nutrition, activity, timing, monitoring, sleep, stress, or general
            4. Indicate priority as: high, medium, or low
            5. Suggest a specific action the user can take (e.g., 'Try taking insulin 20 minutes before your next meal')
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
            "priority ('high'|'medium'|'low'), action (string), timing (string or null), and confidence (float between 0 and 1, representing your confidence in the recommendation). "
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
                        content = completion.choices[0].message.content
                        if content is not None:
                            logger.info("Successfully generated AI recommendations")
                            return content.strip()
                        else:
                            logger.warning("Model API returned None content in choices")
                            return self._fallback_recommendations()
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
                        'confidence': float(item.get('confidence', 0.8)),
                        'action': item.get('action', ''),
                        'timing': item.get('timing', ''),
                        'context': self._attach_examples_and_graph(item)
                    }
                    recommendations.append(rec)
                logger.info(f"Processed {len(recommendations)} recommendations from JSON output: {recommendations}")
                return recommendations[:5]
        except Exception as e:
            logger.warning(f"AI output was not valid JSON, falling back to tolerant parsing: {e}")
            # Try to extract as many valid objects as possible from a partial/truncated JSON array
            # Remove leading/trailing whitespace and brackets
            text = ai_text.strip()
            if text.startswith('['):
                text = text[1:]
            if text.endswith(']'):
                text = text[:-1]
            # Split on '},' to get individual objects (may be incomplete at the end)
            obj_strs = re.split(r'\},\s*\{', text)
            for i, obj_str in enumerate(obj_strs):
                # Add braces back
                if not obj_str.startswith('{'):
                    obj_str = '{' + obj_str
                if not obj_str.endswith('}'):
                    obj_str = obj_str + '}'
                try:
                    item = json.loads(obj_str)
                    rec = {
                        'title': item.get('title', ''),
                        'description': item.get('description', ''),
                        'category': item.get('category', 'general'),
                        'priority': item.get('priority', 'medium'),
                        'confidence': float(item.get('confidence', 0.8)),
                        'action': item.get('action', ''),
                        'timing': item.get('timing', ''),
                        'context': self._attach_examples_and_graph(item)
                    }
                    recommendations.append(rec)
                except Exception:
                    continue
            if recommendations:
                logger.info(f"Processed {len(recommendations)} recommendations from tolerant JSON array parsing")
                return recommendations[:5]
            # If still nothing, try to extract all JSON-like objects from the text (partial/truncated JSON array)
            json_objects = re.findall(r'\{[\s\S]*?\}', ai_text)
            for obj_str in json_objects:
                try:
                    item = json.loads(obj_str)
                    rec = {
                        'title': item.get('title', ''),
                        'description': item.get('description', ''),
                        'category': item.get('category', 'general'),
                        'priority': item.get('priority', 'medium'),
                        'confidence': float(item.get('confidence', 0.8)),
                        'action': item.get('action', ''),
                        'timing': item.get('timing', ''),
                        'context': self._attach_examples_and_graph(item)
                    }
                    recommendations.append(rec)
                except Exception:
                    continue
            if recommendations:
                logger.info(f"Processed {len(recommendations)} recommendations from partial JSON objects in fallback")
                return recommendations[:5]

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
                    'confidence': 0.8,  # Not available in text fallback
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
        """Attach example events, graph data, and supporting data points for drill-down UI."""
        import uuid
        now = datetime.utcnow()
        # Generate a unique recommendation_id for drill-down
        recommendation_id = str(uuid.uuid4())
        # Example: supporting data points (simulate with random for now)
        supporting_data_points = [
            {
                'timestamp': (now - timedelta(hours=3)).isoformat(),
                'value': 250,
                'event_type': rec.get('category', 'general'),
                'note': 'Example spike before meal'
            },
            {
                'timestamp': (now - timedelta(hours=2, minutes=30)).isoformat(),
                'value': 180,
                'event_type': rec.get('category', 'general'),
                'note': 'Glucose after insulin'
            }
        ]
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
                'value': 100 + 40 * math.sin(i/4.0) + random.randint(-10, 10)
            }
            for i in range(48)
        ]
        context = rec.get('context', {}) if 'context' in rec else {}
        context.update({
            'generated_at': now.isoformat(),
            'ai_model': getattr(self, 'model_name', 'unknown'),
            'recommendation_id': recommendation_id,
            'example_event': example_event,
            'graph_data': graph_data,
            'supporting_data_points': supporting_data_points
        })
        return context
    async def explain_recommendation_drilldown(self, recommendation: dict, user: 'User', patterns: dict = None) -> str:
        """
        Generate a focused AI explanation for why a specific recommendation was made, using supporting data points.
        """
        # Build a focused context window
        context = f"""
        Patient Profile:
        - Age: {getattr(user, 'age', 'Unknown')}
        - Gender: {getattr(user, 'gender', 'Unknown')}
        - Diabetes Type: {getattr(user, 'diabetes_type', 'Unknown')}
        - Target Range: {getattr(user, 'target_glucose_min', 70)}-{getattr(user, 'target_glucose_max', 180)} mg/dL
        
        Recommendation to explain:
        - Title: {recommendation.get('title', '')}
        - Description: {recommendation.get('description', '')}
        - Category: {recommendation.get('category', '')}
        - Priority: {recommendation.get('priority', '')}
        - Action: {recommendation.get('action', '')}
        - Timing: {recommendation.get('timing', '')}
        
        Supporting data points:
        """
        supporting = recommendation.get('context', {}).get('supporting_data_points', [])
        for dp in supporting:
            context += f"- {dp.get('timestamp', '')}: {dp.get('event_type', '')} value {dp.get('value', '')} ({dp.get('note', '')})\n"
        context += "\nPlease explain, using the above data, why this recommendation is appropriate for the user. Be specific and reference the supporting data points."
        # Call the AI model for explanation
        ai_explanation = await self._generate_ai_recommendations(context)
        return ai_explanation
    
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
