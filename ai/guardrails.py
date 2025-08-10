# May or may not be used

"""
Clinical guardrails for AI-generated diabetes recommendations.
Call these functions before sending recommendations to the frontend.
If a guardrail is triggered, return a flag and explanation.
"""

def check_insulin_dose(insulin_units: float) -> dict:
    """
    Block/flag if insulin dose is dangerously high (e.g., >15u for a single bolus).
    """
    if insulin_units is not None and insulin_units > 15:
        return {
            "blocked": True,
            "reason": f"Suggested insulin dose ({insulin_units}u) exceeds safe single bolus limit (15u). Please consult your healthcare provider."
        }
    return {"blocked": False}

def check_glucose_target(target_mgdl: float) -> dict:
    """
    Block/flag if glucose target is dangerously low (e.g., <60 mg/dL).
    """
    if target_mgdl is not None and target_mgdl < 60:
        return {
            "blocked": True,
            "reason": f"Suggested glucose target ({target_mgdl} mg/dL) is below safe minimum (60 mg/dL). Please consult your healthcare provider."
        }
    return {"blocked": False}

def apply_guardrails(recommendation: dict) -> dict:
    """
    Check a recommendation dict for dangerous suggestions.
    If a guardrail is triggered, add a 'blocked' flag and reason.
    """
    # Example: check for insulin dose
    if "insulin_units" in recommendation:
        result = check_insulin_dose(recommendation["insulin_units"])
        if result["blocked"]:
            recommendation["blocked"] = True
            recommendation["block_reason"] = result["reason"]
            return recommendation
    # Example: check for glucose target
    if "glucose_target" in recommendation:
        result = check_glucose_target(recommendation["glucose_target"])
        if result["blocked"]:
            recommendation["blocked"] = True
            recommendation["block_reason"] = result["reason"]
            return recommendation
    # Add more guardrails as needed
    recommendation["blocked"] = False
    return recommendation
