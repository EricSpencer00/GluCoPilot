# This file contains functions to generate sample data for development
import datetime
import random
from sqlalchemy.orm import Session
from core.database import SessionLocal
from models.user import User
from models.glucose import Glucose
from models.insulin import Insulin
from models.food import Food
from models.analysis import Analysis
from models.recommendations import Recommendation
from models.health_data import HealthData

def generate_sample_data():
    """Generate sample data for development and testing"""
    db = SessionLocal()
    
    # Create test user if it doesn't exist
    user = db.query(User).filter(User.username == "testuser").first()
    if not user:
        user = User(
            username="testuser",
            email="test@example.com",
            hashed_password="$2b$12$Cr0GrIhxZnIVQXFZcA1IxenIqqXxAUVeaIyDkQG5uIqOBnj9.TX7W",  # password: password123
            is_active=1
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    # Generate 7 days of sample glucose readings
    now = datetime.datetime.now()
    for day in range(7):
        # 24 readings per day (one per hour)
        for hour in range(24):
            timestamp = now - datetime.timedelta(days=day, hours=23-hour)
            
            # Generate a somewhat realistic glucose pattern
            if 7 <= hour <= 9:  # Breakfast spike
                value = random.uniform(140, 180)
            elif 12 <= hour <= 14:  # Lunch spike
                value = random.uniform(130, 170)
            elif 18 <= hour <= 20:  # Dinner spike
                value = random.uniform(135, 175)
            elif 0 <= hour <= 4:  # Night - potential lows
                value = random.uniform(70, 110)
            else:  # Normal range
                value = random.uniform(90, 130)
                
            # Add some randomness
            value += random.uniform(-15, 15)
            
            glucose = Glucose(
                user_id=user.id,
                value=value,
                timestamp=timestamp,
                source=1  # CGM
            )
            db.add(glucose)
    
    # Generate insulin doses (typically with meals)
    for day in range(7):
        # Breakfast insulin
        breakfast_time = now - datetime.timedelta(days=day, hours=random.uniform(7, 8))
        db.add(Insulin(
            user_id=user.id,
            units=random.uniform(4, 6),
            insulin_type="Rapid",
            timestamp=breakfast_time
        ))
        
        # Lunch insulin
        lunch_time = now - datetime.timedelta(days=day, hours=random.uniform(12, 13))
        db.add(Insulin(
            user_id=user.id,
            units=random.uniform(5, 7),
            insulin_type="Rapid",
            timestamp=lunch_time
        ))
        
        # Dinner insulin
        dinner_time = now - datetime.timedelta(days=day, hours=random.uniform(18, 19))
        db.add(Insulin(
            user_id=user.id,
            units=random.uniform(6, 8),
            insulin_type="Rapid",
            timestamp=dinner_time
        ))
        
        # Basal insulin
        basal_time = now - datetime.timedelta(days=day, hours=22)
        db.add(Insulin(
            user_id=user.id,
            units=random.uniform(14, 16),
            insulin_type="Long",
            timestamp=basal_time
        ))
    
    # Generate food entries
    meals = [
        {"name": "Oatmeal with berries", "carbs": 30, "protein": 8, "fat": 3, "calories": 220},
        {"name": "Turkey sandwich", "carbs": 35, "protein": 20, "fat": 8, "calories": 350},
        {"name": "Grilled chicken with vegetables", "carbs": 25, "protein": 35, "fat": 10, "calories": 400},
        {"name": "Greek yogurt with granola", "carbs": 25, "protein": 15, "fat": 5, "calories": 250},
        {"name": "Salmon with quinoa", "carbs": 30, "protein": 30, "fat": 15, "calories": 450},
        {"name": "Vegetable stir-fry", "carbs": 35, "protein": 15, "fat": 7, "calories": 300},
        {"name": "Protein smoothie", "carbs": 20, "protein": 25, "fat": 3, "calories": 230}
    ]
    
    for day in range(7):
        # Breakfast
        breakfast_time = now - datetime.timedelta(days=day, hours=random.uniform(7, 8))
        breakfast = random.choice(meals)
        db.add(Food(
            user_id=user.id,
            name=breakfast["name"],
            carbs=breakfast["carbs"] + random.uniform(-5, 5),
            protein=breakfast["protein"] + random.uniform(-3, 3),
            fat=breakfast["fat"] + random.uniform(-2, 2),
            calories=breakfast["calories"] + random.uniform(-20, 20),
            timestamp=breakfast_time
        ))
        
        # Lunch
        lunch_time = now - datetime.timedelta(days=day, hours=random.uniform(12, 13))
        lunch = random.choice(meals)
        db.add(Food(
            user_id=user.id,
            name=lunch["name"],
            carbs=lunch["carbs"] + random.uniform(-5, 5),
            protein=lunch["protein"] + random.uniform(-3, 3),
            fat=lunch["fat"] + random.uniform(-2, 2),
            calories=lunch["calories"] + random.uniform(-20, 20),
            timestamp=lunch_time
        ))
        
        # Dinner
        dinner_time = now - datetime.timedelta(days=day, hours=random.uniform(18, 19))
        dinner = random.choice(meals)
        db.add(Food(
            user_id=user.id,
            name=dinner["name"],
            carbs=dinner["carbs"] + random.uniform(-5, 5),
            protein=dinner["protein"] + random.uniform(-3, 3),
            fat=dinner["fat"] + random.uniform(-2, 2),
            calories=dinner["calories"] + random.uniform(-20, 20),
            timestamp=dinner_time
        ))
    
    # Generate analysis entries
    analyses = [
        "Your glucose levels show a consistent pattern after meals, with peaks occurring approximately 1-2 hours post-meal.",
        "There appears to be a trend of lower glucose readings in the morning hours (3-6 AM).",
        "Your average glucose level for the week is within target range at 125 mg/dL.",
        "Time in range for the past week is approximately 75%, which is good but could be improved.",
        "There's a noticeable correlation between higher carb intake at dinner and elevated overnight glucose levels."
    ]
    
    for i, analysis_text in enumerate(analyses):
        analysis_time = now - datetime.timedelta(days=i)
        db.add(Analysis(
            user_id=user.id,
            analysis_type="Pattern",
            content=analysis_text,
            timestamp=analysis_time
        ))
    
    # Generate recommendations
    recommendations = [
        "Consider pre-bolusing insulin 15-20 minutes before meals to reduce post-meal spikes.",
        "Your overnight basal dose may need adjustment to address the consistent 3 AM dips.",
        "Adding 5-10 minutes of light activity after meals could help reduce post-meal glucose elevations.",
        "Consider adjusting your insulin-to-carb ratio for dinner meals slightly upward.",
        "Your overall pattern suggests you might benefit from a slight increase in basal insulin."
    ]
    
    for i, recommendation_text in enumerate(recommendations):
        recommendation_time = now - datetime.timedelta(days=i)
        db.add(Recommendation(
            user_id=user.id,
            recommendation_type="Insulin" if i % 2 == 0 else "Activity",
            content=recommendation_text,
            timestamp=recommendation_time
        ))
    
    # Generate health data
    # Weight entries
    for day in range(7):
        if day % 2 == 0:  # Every other day
            weight_time = now - datetime.timedelta(days=day, hours=8)
            db.add(HealthData(
                user_id=user.id,
                data_type="Weight",
                value=75 + random.uniform(-0.5, 0.5),  # kg
                unit="kg",
                timestamp=weight_time
            ))
    
    # Step counts
    for day in range(7):
        steps_time = now - datetime.timedelta(days=day, hours=23)
        db.add(HealthData(
            user_id=user.id,
            data_type="Steps",
            value=random.randint(5000, 12000),
            unit="count",
            timestamp=steps_time
        ))
    
    # Blood pressure
    for day in range(7):
        if day % 3 == 0:  # Every third day
            bp_time = now - datetime.timedelta(days=day, hours=19)
            systolic = random.randint(115, 130)
            diastolic = random.randint(75, 85)
            db.add(HealthData(
                user_id=user.id,
                data_type="Blood Pressure Systolic",
                value=systolic,
                unit="mmHg",
                timestamp=bp_time
            ))
            db.add(HealthData(
                user_id=user.id,
                data_type="Blood Pressure Diastolic",
                value=diastolic,
                unit="mmHg",
                timestamp=bp_time
            ))
    
    db.commit()
    print(f"Generated sample data for user: {user.username}")
    db.close()

if __name__ == "__main__":
    generate_sample_data()
