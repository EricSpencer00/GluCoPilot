# This file contains functions to generate sample data for development
import datetime
import random
import argparse
import json
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import OperationalError
from core.database import SessionLocal, engine
from models.user import User
from models.glucose import Glucose
from models.insulin import Insulin
from models.food import Food
from models.analysis import Analysis
from models.recommendations import Recommendation
from models.health_data import HealthData
from models.activity import Activity
from models.sleep import Sleep
from models.mood import Mood
from models.medication import Medication
from models.illness import Illness
from models.menstrual_cycle import MenstrualCycle

def generate_sample_data(user_id=None, include_all_streams=False):
    """Generate sample data for development and testing"""
    db = SessionLocal()
    
    # Create test user if it doesn't exist or use the specified user
    if user_id:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            print(f"User with ID {user_id} not found. Creating a test user instead.")
            user_id = None
    
    if not user_id:
        user = db.query(User).filter(User.username == "testuser").first()
        if not user:
            user = User(
                username="testuser",
                email="test@example.com",
                hashed_password="$2b$12$Cr0GrIhxZnIVQXFZcA1IxenIqqXxAUVeaIyDkQG5uIqOBnj9.TX7W",  # password: password123
                is_active=1,
                height_cm=175.5,
                weight_kg=75.2,
                birthdate=datetime.datetime(1990, 1, 15),
                gender="Male",
                diabetes_type=1,
                diagnosis_date=datetime.datetime(2010, 3, 10),
                notification_preferences=json.dumps({"glucose_alerts": True, "meal_reminders": True}),
                privacy_preferences=json.dumps({"share_data_with_researchers": False, "anonymize_data": True}),
                apple_health_authorized=True,
                myfitnesspal_username="testuser"
            )
            db.add(user)
            db.commit()
            db.refresh(user)
    else:
        user = db.query(User).filter(User.id == user_id).first()
    
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
        {"name": "Oatmeal with berries", "carbs": 30, "protein": 8, "fat": 3, "calories": 220, "fiber": 5, "sugar": 10, "gi": 55},
        {"name": "Turkey sandwich", "carbs": 35, "protein": 20, "fat": 8, "calories": 350, "fiber": 4, "sugar": 5, "gi": 70},
        {"name": "Grilled chicken with vegetables", "carbs": 25, "protein": 35, "fat": 10, "calories": 400, "fiber": 6, "sugar": 8, "gi": 45},
        {"name": "Greek yogurt with granola", "carbs": 25, "protein": 15, "fat": 5, "calories": 250, "fiber": 3, "sugar": 15, "gi": 60},
        {"name": "Salmon with quinoa", "carbs": 30, "protein": 30, "fat": 15, "calories": 450, "fiber": 7, "sugar": 2, "gi": 50},
        {"name": "Vegetable stir-fry", "carbs": 35, "protein": 15, "fat": 7, "calories": 300, "fiber": 8, "sugar": 10, "gi": 40},
        {"name": "Protein smoothie", "carbs": 20, "protein": 25, "fat": 3, "calories": 230, "fiber": 4, "sugar": 14, "gi": 35}
    ]
    
    meal_types = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
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
            timestamp=breakfast_time,
            meal_type="Breakfast",
            fiber=breakfast["fiber"] + random.uniform(-1, 1),
            sugar=breakfast["sugar"] + random.uniform(-2, 2),
            glycemic_index=breakfast["gi"] + random.randint(-5, 5),
            glycemic_load=(breakfast["gi"] * breakfast["carbs"]) / 100,
            serving_size=1.0,
            serving_unit="bowl",
            source="manual"
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
            timestamp=lunch_time,
            meal_type="Lunch",
            fiber=lunch["fiber"] + random.uniform(-1, 1),
            sugar=lunch["sugar"] + random.uniform(-2, 2),
            glycemic_index=lunch["gi"] + random.randint(-5, 5),
            glycemic_load=(lunch["gi"] * lunch["carbs"]) / 100,
            serving_size=1.0,
            serving_unit="plate",
            source="manual"
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
            timestamp=dinner_time,
            meal_type="Dinner",
            fiber=dinner["fiber"] + random.uniform(-1, 1),
            sugar=dinner["sugar"] + random.uniform(-2, 2),
            glycemic_index=dinner["gi"] + random.randint(-5, 5),
            glycemic_load=(dinner["gi"] * dinner["carbs"]) / 100,
            serving_size=1.0,
            serving_unit="plate",
            source="manual"
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
        {"text": "Consider pre-bolusing insulin 15-20 minutes before meals to reduce post-meal spikes.", "action": "Take insulin 15-20 minutes before your next meal"},
        {"text": "Your overnight basal dose may need adjustment to address the consistent 3 AM dips.", "action": "Increase basal insulin by 1 unit at bedtime"},
        {"text": "Adding 5-10 minutes of light activity after meals could help reduce post-meal glucose elevations.", "action": "Take a short walk after lunch today"},
        {"text": "Consider adjusting your insulin-to-carb ratio for dinner meals slightly upward.", "action": "Increase dinner insulin ratio from 1:10 to 1:8"},
        {"text": "Your overall pattern suggests you might benefit from a slight increase in basal insulin.", "action": "Discuss basal rate adjustment with your doctor"}
    ]
    
    for i, recommendation_data in enumerate(recommendations):
        recommendation_time = now - datetime.timedelta(days=i)
        suggested_time = now + datetime.timedelta(hours=i+1)
        db.add(Recommendation(
            user_id=user.id,
            recommendation_type="Insulin" if i % 2 == 0 else "Activity",
            content=recommendation_data["text"],
            timestamp=recommendation_time,
            suggested_action=recommendation_data["action"],
            suggested_time=suggested_time,
            action_taken=False
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
    
    # Generate additional data streams if requested
    if include_all_streams:
        # Generate activity logs
        activity_types = ["Walking", "Running", "Cycling", "Swimming", "Weight Training", "Yoga", "HIIT"]
        intensities = ["Low", "Moderate", "High"]
        
        for day in range(7):
            for _ in range(random.randint(1, 3)):  # 1-3 activities per day
                activity_time = now - datetime.timedelta(
                    days=day, 
                    hours=random.randint(8, 20), 
                    minutes=random.randint(0, 59)
                )
                activity_type = random.choice(activity_types)
                intensity = random.choice(intensities)
                
                # Duration depends on activity type and intensity
                if activity_type in ["HIIT", "Weight Training"]:
                    duration = random.randint(15, 45)
                elif activity_type in ["Running", "Swimming"]:
                    duration = random.randint(20, 60)
                else:
                    duration = random.randint(30, 90)
                
                # Adjust duration based on intensity
                if intensity == "Low":
                    duration = int(duration * 1.2)
                elif intensity == "High":
                    duration = int(duration * 0.8)
                
                # Calculate calories burned (simplified formula)
                calories_burned = duration * (5 if intensity == "Low" else 8 if intensity == "Moderate" else 12)
                
                # Generate heart rate based on intensity
                heart_rate = 70 + (20 if intensity == "Low" else 40 if intensity == "Moderate" else 60)
                heart_rate += random.randint(-10, 10)  # Add some variation
                
                db.add(Activity(
                    user_id=user.id,
                    activity_type=activity_type,
                    duration_minutes=duration,
                    intensity=intensity,
                    calories_burned=calories_burned,
                    steps=random.randint(duration * 80, duration * 120) if activity_type in ["Walking", "Running"] else None,
                    heart_rate_avg=heart_rate,
                    timestamp=activity_time,
                    source="Apple Health" if random.random() > 0.5 else "manual"
                ))
        
        # Generate sleep logs
        for day in range(7):
            # Sleep start (previous night)
            sleep_start = now - datetime.timedelta(
                days=day+1,
                hours=random.randint(22, 23),
                minutes=random.randint(0, 59)
            )
            
            # Sleep duration varies 6-9 hours
            sleep_duration = random.randint(360, 540)
            
            # Sleep end
            sleep_end = sleep_start + datetime.timedelta(minutes=sleep_duration)
            
            # Sleep quality (1-10)
            quality = random.randint(5, 10)
            
            # Sleep phases
            deep_sleep = int(sleep_duration * random.uniform(0.15, 0.25))
            rem_sleep = int(sleep_duration * random.uniform(0.2, 0.3))
            light_sleep = sleep_duration - deep_sleep - rem_sleep - random.randint(10, 30)
            awake_minutes = sleep_duration - deep_sleep - rem_sleep - light_sleep
            
            db.add(Sleep(
                user_id=user.id,
                start_time=sleep_start,
                end_time=sleep_end,
                duration_minutes=sleep_duration,
                quality=quality,
                deep_sleep_minutes=deep_sleep,
                light_sleep_minutes=light_sleep,
                rem_sleep_minutes=rem_sleep,
                awake_minutes=awake_minutes,
                heart_rate_avg=random.randint(50, 65),
                source="Apple Health" if random.random() > 0.5 else "manual"
            ))
        
        # Generate mood logs
        moods = [
            {"rating": 9, "description": "Energetic and optimistic"},
            {"rating": 8, "description": "Content and relaxed"},
            {"rating": 7, "description": "Generally good mood"},
            {"rating": 6, "description": "Slightly tired but ok"},
            {"rating": 5, "description": "Neutral mood"},
            {"rating": 4, "description": "A bit stressed"},
            {"rating": 3, "description": "Tired and irritable"}
        ]
        
        mood_tags = ["work", "family", "exercise", "sleep", "food", "glucose", "weather", "socializing"]
        
        for day in range(7):
            # Log 1-3 moods per day
            for _ in range(random.randint(1, 3)):
                mood_time = now - datetime.timedelta(
                    days=day,
                    hours=random.randint(8, 22),
                    minutes=random.randint(0, 59)
                )
                
                mood_data = random.choice(moods)
                # Add some random variation to mood
                mood_rating = max(1, min(10, mood_data["rating"] + random.randint(-1, 1)))
                
                # Select 0-3 random tags
                selected_tags = ",".join(random.sample(mood_tags, random.randint(0, 3))) if random.random() > 0.3 else None
                
                db.add(Mood(
                    user_id=user.id,
                    rating=mood_rating,
                    description=mood_data["description"],
                    tags=selected_tags,
                    timestamp=mood_time
                ))
        
        # Generate medication logs
        medications = [
            {"name": "Metformin", "dosage": "500", "units": "mg"},
            {"name": "Lisinopril", "dosage": "10", "units": "mg"},
            {"name": "Multivitamin", "dosage": "1", "units": "tablet"},
            {"name": "Vitamin D", "dosage": "2000", "units": "IU"},
            {"name": "Aspirin", "dosage": "81", "units": "mg"}
        ]
        
        # Assign 1-3 medications to the user
        user_medications = random.sample(medications, random.randint(1, 3))
        
        for day in range(7):
            for medication in user_medications:
                # Morning medications
                morning_time = now - datetime.timedelta(
                    days=day,
                    hours=random.randint(6, 9),
                    minutes=random.randint(0, 59)
                )
                
                # Not every medication is taken every day
                if random.random() > 0.1:  # 90% adherence
                    db.add(Medication(
                        user_id=user.id,
                        name=medication["name"],
                        dosage=medication["dosage"],
                        units=medication["units"],
                        timestamp=morning_time,
                        taken=True,
                        notes="Regular morning dose"
                    ))
                
                # Evening medications (if applicable)
                if medication["name"] in ["Metformin", "Lisinopril"]:
                    evening_time = now - datetime.timedelta(
                        days=day,
                        hours=random.randint(18, 22),
                        minutes=random.randint(0, 59)
                    )
                    
                    if random.random() > 0.15:  # 85% adherence for evening doses
                        db.add(Medication(
                            user_id=user.id,
                            name=medication["name"],
                            dosage=medication["dosage"],
                            units=medication["units"],
                            timestamp=evening_time,
                            taken=True,
                            notes="Regular evening dose"
                        ))
        
        # Generate illness logs (less frequent)
        illnesses = [
            {"name": "Common Cold", "severity": 3, "symptoms": "Congestion, sore throat, cough"},
            {"name": "Mild Flu", "severity": 5, "symptoms": "Fever, body aches, fatigue"},
            {"name": "Seasonal Allergies", "severity": 2, "symptoms": "Itchy eyes, sneezing, runny nose"},
            {"name": "Migraine", "severity": 4, "symptoms": "Headache, sensitivity to light, nausea"},
            {"name": "Stomach Bug", "severity": 6, "symptoms": "Nausea, vomiting, diarrhea"}
        ]
        
        # 30% chance of having been sick in the past week
        if random.random() < 0.3:
            illness = random.choice(illnesses)
            illness_start = now - datetime.timedelta(
                days=random.randint(3, 7),
                hours=random.randint(0, 23)
            )
            
            # Illness duration based on severity
            duration_days = illness["severity"] / 2
            
            # 70% chance the illness has ended
            if random.random() < 0.7:
                illness_end = illness_start + datetime.timedelta(days=duration_days)
            else:
                illness_end = None
            
            db.add(Illness(
                user_id=user.id,
                name=illness["name"],
                severity=illness["severity"],
                symptoms=illness["symptoms"],
                start_date=illness_start,
                end_date=illness_end,
                notes="Affected glucose levels" if random.random() > 0.5 else None
            ))
        
        # Generate menstrual cycle data (if applicable)
        if user.gender == "Female":
            # Create 3 recent menstrual cycles
            for i in range(3):
                cycle_start = now - datetime.timedelta(days=28*i + random.randint(0, 3))
                period_length = random.randint(4, 7)
                cycle_end = cycle_start + datetime.timedelta(days=period_length)
                
                flow_level = random.randint(1, 5)
                symptoms = random.choice([
                    "Cramps, bloating", 
                    "Headache, fatigue", 
                    "Mood swings, breast tenderness", 
                    "Back pain, cramps", 
                    "Minimal symptoms"
                ])
                
                db.add(MenstrualCycle(
                    user_id=user.id,
                    start_date=cycle_start,
                    end_date=cycle_end,
                    cycle_length=28 + random.randint(-2, 2),
                    period_length=period_length,
                    symptoms=symptoms,
                    flow_level=flow_level,
                    notes="Affected glucose levels" if random.random() > 0.5 else None
                ))
    
    db.commit()
    print(f"Generated sample data for user: {user.username} (ID: {user.id})")
    if include_all_streams:
        print("Generated additional data streams for comprehensive analysis")
    db.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate sample data for GluCoPilot')
    parser.add_argument('--user_id', type=int, help='User ID to generate data for')
    parser.add_argument('--include_all_streams', action='store_true', help='Include all data streams for comprehensive analysis')
    
    args = parser.parse_args()
    
    # Check if tables exist and create them if needed
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1 FROM users LIMIT 1"))
        print("Database tables exist. Proceeding with sample data generation.")
    except OperationalError:
        print("Database tables don't exist. Please run migrations first.")
        exit(1)
    
    generate_sample_data(args.user_id, args.include_all_streams)
