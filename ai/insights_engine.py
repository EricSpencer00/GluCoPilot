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
        db: Session
    ) -> List[Dict[str, Any]]:
        """Generate personalized recommendations based on user data"""
        
        if not self.initialized:
            await self.initialize()
        
        logger.info(f"Generating recommendations for user {user.id}")
        
        try:
            # Analyze patterns
            patterns = await self._analyze_patterns(glucose_data, insulin_data, food_data)
            
            # Create context for AI model
            context = self._create_recommendation_context(user, patterns, glucose_data, insulin_data, food_data)
            
            # Generate recommendations using AI
            ai_recommendations = await self._generate_ai_recommendations(context)
            
            # Process and validate recommendations
            processed_recommendations = self._process_recommendations(ai_recommendations, user.id)
            
            # Store recommendations in database using only allowed fields
            stored_recommendations = []
            for rec_data in processed_recommendations:
                recommendation = Recommendation(
                    user_id=user.id,
                    recommendation_type=rec_data.get('category', 'general'),
                    content=rec_data.get('description', '')
                )
                db.add(recommendation)
                stored_recommendations.append(recommendation)
            db.commit()
            logger.info(f"Generated {len(stored_recommendations)} recommendations")
            # Return a simple dict for API response
            return [
                {
                    'id': rec.id,
                    'recommendation_type': rec.recommendation_type,
                    'content': rec.content,
                    'timestamp': rec.timestamp.isoformat() if rec.timestamp else None
                }
                for rec in stored_recommendations
            ]
        
        except Exception as e:
            logger.error(f"Error generating recommendations: {str(e)}")
            db.rollback()
            return []
    
    async def _analyze_patterns(
        self,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food]
    ) -> Dict[str, Any]:
        """Analyze data patterns"""
        
        patterns = {
            'glucose_patterns': self._analyze_glucose_patterns(glucose_data),
            'meal_patterns': self._analyze_meal_patterns(glucose_data, food_data),
            'insulin_patterns': self._analyze_insulin_patterns(glucose_data, insulin_data),
            'time_patterns': self._analyze_time_patterns(glucose_data),
            'variability': self._analyze_variability(glucose_data)
        }
        
        return patterns
    
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
    
    def _create_recommendation_context(
        self,
        user: User,
        patterns: Dict[str, Any],
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food]
    ) -> str:
        """Create context string for AI model"""
        
        # Handle missing date_of_birth gracefully
        if hasattr(user, "date_of_birth") and user.date_of_birth:
            age = (datetime.now() - user.date_of_birth).days // 365
        else:
            age = 'Unknown'
        context = f"""
Patient Profile:
- Age: {age}
- Target Range: {getattr(user, 'target_glucose_min', 'Unknown')}-{getattr(user, 'target_glucose_max', 'Unknown')} mg/dL
- Insulin-to-Carb Ratio: 1:{getattr(user, 'insulin_carb_ratio', 'Unknown')}
- Correction Factor: {getattr(user, 'insulin_sensitivity_factor', 'Unknown')}

Current Glucose Patterns:
- Average Glucose: {patterns['glucose_patterns'].get('average', 'Unknown'):.1f} mg/dL
- Time in Range: {patterns['glucose_patterns'].get('time_in_range', 0):.1f}%
- Glucose Variability: {patterns['variability'].get('coefficient_of_variation', 0):.1f}%

Recent Data Summary:
- Glucose readings: {len(glucose_data)} in last 24 hours
- Insulin doses: {len(insulin_data)} in last 24 hours
- Meals logged: {len(food_data)} in last 24 hours

Key Observations:
- Dawn phenomenon present: {patterns['glucose_patterns'].get('dawn_phenomenon', False)}
- Frequent highs (>250): {patterns['glucose_patterns'].get('frequent_highs', 0):.1f}%
- Frequent lows (<70): {patterns['glucose_patterns'].get('frequent_lows', 0):.1f}%

Please provide 3-5 specific, actionable recommendations to improve glucose control based on this data.
Focus on timing, dosing, and lifestyle modifications. Keep recommendations concise and practical.
"""
        return context
    
    async def _generate_ai_recommendations(self, context: str) -> str:
        """Generate recommendations using AI model or Inference API"""
        prompt = f"{context}\n\nRecommendations:"
        try:
            if settings.MODEL_NAME == "openai/gpt-oss-20b":
                # Use Hugging Face Inference API
                api_url = f"https://api-inference.huggingface.co/models/{settings.MODEL_NAME}"
                headers = {"Authorization": f"Bearer {settings.HUGGINGFACE_TOKEN}"}
                payload = {"inputs": prompt, "parameters": {"max_new_tokens": 256, "temperature": 0.7}}
                response = requests.post(api_url, headers=headers, json=payload, timeout=60)
                response.raise_for_status()
                result = response.json()
                if isinstance(result, list) and len(result) > 0 and "generated_text" in result[0]:
                    generated_text = result[0]["generated_text"]
                elif isinstance(result, dict) and "error" in result:
                    logger.error(f"HF Inference API error: {result['error']}")
                    return self._fallback_recommendations()
                else:
                    generated_text = str(result)
                recommendations_start = generated_text.find("Recommendations:")
                if recommendations_start != -1:
                    return generated_text[recommendations_start + len("Recommendations:"):].strip()
                return generated_text
            else:
                # Use local/transformers pipeline
                response = self.generator(
                    prompt,
                    max_new_tokens=256,
                    temperature=0.7,
                    do_sample=True,
                    pad_token_id=self.generator.tokenizer.eos_token_id
                )
                if isinstance(response, list) and len(response) > 0:
                    generated_text = response[0]['generated_text']
                    recommendations_start = generated_text.find("Recommendations:")
                    if recommendations_start != -1:
                        return generated_text[recommendations_start + len("Recommendations:"):].strip()
                return response if isinstance(response, str) else ""
        except Exception as e:
            logger.error(f"Error generating AI recommendations: {str(e)}")
            return self._fallback_recommendations()
    
    def _fallback_recommendations(self) -> str:
        """Provide fallback recommendations when AI generation fails"""
        return """
1. Monitor glucose trends closely and look for patterns related to meals and insulin timing.
2. Consider adjusting insulin-to-carb ratios if post-meal glucose spikes are frequent.
3. Maintain consistent meal timing and carbohydrate intake to improve glucose stability.
4. Review correction factor if high glucose readings persist despite correction doses.
5. Consult with healthcare provider for personalized adjustment recommendations.
"""
    
    def _process_recommendations(self, ai_text: str, user_id: int) -> List[Dict[str, Any]]:
        """Process AI-generated text into structured recommendations"""
        recommendations = []
        
        # Split by numbered points
        lines = ai_text.strip().split('\n')
        current_rec = ""
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Check if this is a new numbered recommendation
            if line[0].isdigit() and ('.' in line[:5] or ')' in line[:5]):
                # Process previous recommendation
                if current_rec:
                    rec_data = self._parse_recommendation(current_rec, user_id)
                    if rec_data:
                        recommendations.append(rec_data)
                
                current_rec = line
            else:
                current_rec += " " + line
        
        # Process the last recommendation
        if current_rec:
            rec_data = self._parse_recommendation(current_rec, user_id)
            if rec_data:
                recommendations.append(rec_data)
        
        return recommendations[:5]  # Limit to 5 recommendations
    
    def _parse_recommendation(self, rec_text: str, user_id: int) -> Optional[Dict[str, Any]]:
        """Parse a single recommendation text into structured data"""
        if not rec_text or len(rec_text.strip()) < 10:
            return None
        
        # Remove numbering
        text = rec_text
        if text[0].isdigit():
            text = text[text.find('.') + 1:].strip() if '.' in text else text[1:].strip()
        
        # Determine category and priority based on keywords
        category = self._categorize_recommendation(text)
        priority = self._prioritize_recommendation(text)
        
        # Extract title (first sentence or up to 60 chars)
        title = text.split('.')[0][:60] + ('...' if len(text.split('.')[0]) > 60 else '')
        
        return {
            'title': title,
            'description': text,
            'category': category,
            'priority': priority,
            'confidence': 0.8,  # Default confidence score
            'context': {
                'generated_at': datetime.utcnow().isoformat(),
                'ai_model': self.model_name
            }
        }
    
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
