"""
DEPRECATED: AIInsightsEngine implementation moved to ai/insights_engine_core.py
This file remains as a thin wrapper for backward compatibility.
"""

# Re-export the core implementation
from .insights_engine_core import AIInsightsEngine

__all__ = ["AIInsightsEngine"]
