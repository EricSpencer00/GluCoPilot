# This file marks the directory as a Python package.
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from models.analysis import Analysis
from models.recommendations import Recommendation
from models.health_data import HealthData
from models.prediction import PredictionModel, GlucosePrediction
from models.activity import Activity
from models.sleep import Sleep
from models.mood import Mood
from models.medication import Medication, Illness
from models.menstrual_cycle import MenstrualCycle

# Make these modules accessible from the models package
user = User
glucose = GlucoseReading
insulin = Insulin
food = Food
analysis = Analysis
recommendations = Recommendation
health_data = HealthData
prediction_model = PredictionModel
glucose_prediction = GlucosePrediction
activity = Activity
sleep = Sleep
mood = Mood
medication = Medication
illness = Illness
menstrual_cycle = MenstrualCycle