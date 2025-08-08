# API routers package
from . import auth, glucose, insulin, food, analysis, recommendations, health

__all__ = [
    "auth",
    "glucose", 
    "insulin",
    "food",
    "analysis",
    "recommendations",
    "health"
]
