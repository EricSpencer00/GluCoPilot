import os
import json
from ai.insights_engine_core import AIInsightsEngine

# Simulate a truncated model output similar to logs
TRUNCATED = (
    '[\n  {\n    "title": "Set up insulin dose logging",\n    "description": "Recording every insulin dose is essential for accurate glucose control and future adjustments.",\n    "category": "insulin",\n    "priority": "high",\n    "confidence": 0.9,\n    "action": "Open your diabetes app and log each insulin dose you administer, including time, unit, and type (bolus or basal).",\n    '
)

if __name__ == "__main__":
    eng = AIInsightsEngine()
    recs = eng._process_recommendations(TRUNCATED, user_id=0)
    print(f"Parsed {len(recs)} recommendations")
    for i, r in enumerate(recs[:3], 1):
        print(i, r.get('title'), '-', r.get('category'))
