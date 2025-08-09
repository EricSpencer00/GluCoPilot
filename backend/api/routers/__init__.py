# Import all routers
from .auth import router as auth_router
from .glucose import router as glucose_router
from .prediction import router as prediction_router

# These will be needed when implemented
try:
    from .insulin import router as insulin_router
except ImportError:
    pass

try:
    from .food import router as food_router
except ImportError:
    pass

try:
    from .analysis import router as analysis_router
except ImportError:
    pass

try:
    from .recommendations import router as recommendations_router
except ImportError:
    pass

try:
    from .health import router as health_router
except ImportError:
    pass

# Re-export for easier imports
auth = auth_router
glucose = glucose_router
prediction = prediction_router
# Set these to None or create placeholder routers if they don't exist
insulin = insulin_router if 'insulin_router' in locals() else None
food = food_router if 'food_router' in locals() else None
analysis = analysis_router if 'analysis_router' in locals() else None
recommendations = recommendations_router if 'recommendations_router' in locals() else None
health = health_router if 'health_router' in locals() else None
