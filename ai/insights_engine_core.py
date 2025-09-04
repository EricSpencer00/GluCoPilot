# Lightweight core implementation of AIInsightsEngine for Heroku
import os
import json
import re
import uuid
import math
import random
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from typing import Dict, Any  # Ensure explicit import for type hints

from core.config import settings
from models.user import User
from models.glucose import GlucoseReading
from models.insulin import Insulin
from models.food import Food
from models.activity import Activity
from models.sleep import Sleep
from models.mood import Mood
from models.medication import Medication, Illness
from models.menstrual_cycle import MenstrualCycle
from models.health_data import HealthData
from models.recommendations import Recommendation
from utils.logging import get_logger

logger = get_logger(__name__)


class AIInsightsEngine:
    def __init__(self):
        self.model_name = "openai/gpt-oss-20b"

    async def generate_recommendations(
        self,
        user: User,
        glucose_data: List[GlucoseReading],
        insulin_data: List[Insulin],
        food_data: List[Food],
        db: Optional[Any] = None,
        activity_data: Optional[List[Activity]] = None,
        sleep_data: Optional[List[Sleep]] = None,
        mood_data: Optional[List[Mood]] = None,
        medication_data: Optional[List[Medication]] = None,
        illness_data: Optional[List[Illness]] = None,
        menstrual_cycle_data: Optional[List[MenstrualCycle]] = None,
        health_data: Optional[List[HealthData]] = None,
    ) -> List[Dict[str, Any]]:
        logger.info(f"Generating recommendations for user {getattr(user, 'id', 'unknown')}")
        try:
            # Default empty lists for optional params
            activity_data = activity_data or []
            sleep_data = sleep_data or []
            mood_data = mood_data or []
            medication_data = medication_data or []
            illness_data = illness_data or []
            menstrual_cycle_data = menstrual_cycle_data or []
            health_data = health_data or []

            # Analyze minimal patterns needed for context
            patterns = await self._analyze_all_patterns(
                glucose_data,
                insulin_data,
                food_data,
                activity_data,
                sleep_data,
                mood_data,
                medication_data,
                illness_data,
                menstrual_cycle_data,
                health_data,
            )

            # Build context
            context = self._create_comprehensive_context(
                user,
                patterns,
                glucose_data,
                insulin_data,
                food_data,
                activity_data,
                sleep_data,
                mood_data,
                medication_data,
                illness_data,
                menstrual_cycle_data,
                health_data,
            )

            # Call AI
            ai_text = await self._generate_ai_recommendations(context, glucose_data=glucose_data, patterns=patterns)

            # Parse and enrich
            recommendations = self._process_recommendations(ai_text, getattr(user, 'id', 0))

            # Fill suggested times if missing
            now = datetime.utcnow()
            for rec in recommendations:
                if not rec.get('timing'):
                    rec['timing'] = self._calculate_suggested_time(rec, now).isoformat()

            return recommendations
        except Exception as e:
            logger.error(f"Error generating recommendations: {e}")
            return [
                {
                    'title': "Error generating recommendations",
                    'description': "An error occurred while analyzing your data. Please try again later.",
                    'category': 'general',
                    'priority': 'medium',
                    'confidence': 0.5,
                    'action': "Try again later or contact support if the problem persists.",
                    'timing': (datetime.utcnow() + timedelta(hours=1)).isoformat(),
                }
            ]

    async def explain_recommendation_drilldown(self, recommendation: dict, user: User, patterns: dict | None = None) -> str:
        """Generate a focused AI explanation for a specific recommendation."""
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
        return await self._generate_ai_recommendations(context)

    # -------------------- Minimal analytics used by context --------------------
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
        health_data: List[HealthData],
    ) -> Dict[str, Any]:
        return {
            'glucose_patterns': self._analyze_glucose_patterns(glucose_data),
            'variability': self._analyze_variability(glucose_data),
        }

    def _analyze_glucose_patterns(self, glucose_data: List[GlucoseReading]) -> Dict[str, Any]:
        if not glucose_data:
            return {}
        vals = [g.value for g in glucose_data]
        avg = sum(vals) / len(vals) if vals else 0.0
        in_range = len([v for v in vals if 70 <= v <= 180]) / len(vals) * 100 if vals else 0.0
        highs = len([v for v in vals if v > 250]) / len(vals) * 100 if vals else 0.0
        lows = len([v for v in vals if v < 70]) / len(vals) * 100 if vals else 0.0
        return {
            'average': avg,
            'time_in_range': in_range,
            'frequent_highs': highs,
            'frequent_lows': lows,
        }

    def _analyze_variability(self, glucose_data: List[GlucoseReading]) -> Dict[str, Any]:
        vals = [g.value for g in glucose_data]
        if len(vals) < 2:
            return {'coefficient_of_variation': 0.0}
        mean = sum(vals) / len(vals)
        var = sum((v - mean) ** 2 for v in vals) / (len(vals) - 1) if len(vals) > 1 else 0.0
        std = math.sqrt(var)
        cov = (std / mean * 100) if mean else 0.0
        return {'coefficient_of_variation': cov}

    # -------------------- Context and helpers --------------------
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
        health_data: List[HealthData],
    ) -> str:
        age = getattr(user, 'age', 'Unknown')
        now = datetime.utcnow()
        recent_glucose = [g for g in glucose_data if g.timestamp >= now - timedelta(hours=24)]
        recent_insulin = [i for i in insulin_data if i.timestamp >= now - timedelta(hours=24)]
        recent_food = [f for f in food_data if f.timestamp >= now - timedelta(hours=24)]
        recent_activity = [a for a in activity_data if a.timestamp >= now - timedelta(hours=24)]
        recent_sleep = [s for s in sleep_data if getattr(s, 'start_time', now) >= now - timedelta(days=7)]
        recent_mood = [m for m in mood_data if m.timestamp >= now - timedelta(days=7)]

        spike_events = self._find_meal_insulin_spike_events(glucose_data, insulin_data, food_data)
        spike_summaries = ""
        if spike_events:
            spike_summaries += "\nRecent meal-insulin-glucose spike events detected:\n"
            for e in spike_events:
                spike_summaries += (
                    f"- At {e['meal_time'].strftime('%Y-%m-%d %H:%M')}, took {e['insulin']}u at {e['insulin_time'].strftime('%H:%M')}, "
                    f"ate {e['carbs']}g, glucose {e['pre_glucose']} -> {e['peak_glucose']} mg/dL (spike {e['spike']}).\n"
                )
            spike_summaries += "Suggest prebolus timing or I:C ratio adjustments.\n"

        def _fmt(val):
            return f"{val:.1f}" if isinstance(val, (int, float)) else str(val)

        return f"""
            Patient Profile:
            - Age: {age}
            - Gender: {getattr(user, 'gender', 'Unknown')}
            - Diabetes Type: {getattr(user, 'diabetes_type', 'Unknown')}
            - Target Range: {getattr(user, 'target_glucose_min', 70)}-{getattr(user, 'target_glucose_max', 180)} mg/dL
            - Insulin-to-Carb Ratio: 1:{getattr(user, 'insulin_carb_ratio', 'Unknown')}
            - Correction Factor: {getattr(user, 'insulin_sensitivity_factor', 'Unknown')}
            {spike_summaries}

            Current Glucose Patterns (24-hour analysis):
            - Average Glucose: {_fmt(patterns.get('glucose_patterns', {}).get('average', 'Unknown'))} mg/dL
            - Time in Range: {_fmt(patterns.get('glucose_patterns', {}).get('time_in_range', 'Unknown'))}%
            - Glucose Variability: {_fmt(patterns.get('variability', {}).get('coefficient_of_variation', 'Unknown'))}%
            - Frequent highs (>250): {_fmt(patterns.get('glucose_patterns', {}).get('frequent_highs', 'Unknown'))}%
            - Frequent lows (<70): {_fmt(patterns.get('glucose_patterns', {}).get('frequent_lows', 'Unknown'))}%

            Recent Data Summary:
            - Glucose readings: {len(recent_glucose)} in last 24 hours
            - Insulin doses: {len(recent_insulin)} in last 24 hours
            - Meals logged: {len(recent_food)} in last 24 hours
            - Activity sessions: {len(recent_activity)} in last 24 hours
            - Sleep logs: {len(recent_sleep)} in last week
            - Mood logs: {len(recent_mood)} in last week

            Provide 5 specific, actionable recommendations as a JSON array.
            Each item: title, description, category (insulin|nutrition|activity|timing|monitoring|sleep|stress|general),
            priority (high|medium|low), action, timing (string or null), confidence (0..1).
            Output ONLY JSON.
        """

    def _find_meal_insulin_spike_events(self, glucose_data, insulin_data, food_data):
        if not glucose_data or not insulin_data or not food_data:
            return []
        events = []
        for food in food_data:
            meal_time = food.timestamp
            relevant_insulin = [
                i for i in insulin_data if meal_time - timedelta(hours=1) <= i.timestamp <= meal_time + timedelta(minutes=15)
            ]
            if not relevant_insulin:
                continue
            insulin = min(relevant_insulin, key=lambda i: abs((i.timestamp - meal_time).total_seconds()))
            pre_meal = [g for g in glucose_data if meal_time - timedelta(minutes=30) <= g.timestamp <= meal_time]
            pre_val = pre_meal[-1].value if pre_meal else None
            post_meal = [g for g in glucose_data if meal_time < g.timestamp <= meal_time + timedelta(hours=3)]
            if not post_meal or pre_val is None:
                continue
            peak = max(post_meal, key=lambda g: g.value)
            spike = peak.value - pre_val
            if spike > 40 and getattr(food, 'total_carbs', getattr(food, 'carbs', 0)) >= 20:
                events.append(
                    {
                        'meal_time': meal_time,
                        'carbs': getattr(food, 'total_carbs', getattr(food, 'carbs', 0)),
                        'insulin': insulin.units,
                        'insulin_time': insulin.timestamp,
                        'pre_glucose': pre_val,
                        'peak_glucose': peak.value,
                        'peak_time': peak.timestamp,
                        'spike': spike,
                    }
                )
        return events

    # -------------------- AI call and parsing --------------------
    async def _generate_ai_recommendations(self, context: str, glucose_data: Optional[List[GlucoseReading]] = None, patterns: Optional[Dict[str, Any]] = None) -> str:
        prompt = f"{context}\n\nRecommendations:"
        json_instructions = """
        IMPORTANT: Return your response as a JSON array of recommendation objects, with exactly 5 recommendations.
        Each recommendation object must have this exact structure:
        {
          "title": "Short, actionable title",
          "description": "Detailed explanation (1-3 sentences)",
          "category": "One of: insulin, glucose, nutrition, activity, sleep, stress, monitoring, general",
          "priority": "One of: high, medium, low",
          "confidence": 0.7,  // A number between 0.0 and 1.0
          "action": "Clear next step the user should take",
          "timing": "When to take action (can be null)"
        }
        
        Your response must be a valid JSON array that can be parsed with json.loads().
        Do not include any text outside the JSON array.
        Do not include ```json or ``` markdown code block markers.
        
        Example of a correct response format:
        [
          {
            "title": "Example recommendation 1",
            "description": "Description text here.",
            "category": "general",
            "priority": "medium",
            "confidence": 0.8,
            "action": "Action text here",
            "timing": null
          },
          // 4 more recommendations...
        ]
        """

        try:
            # Prefer remote model when enabled via settings, regardless of exact model name string
            if getattr(settings, "USE_REMOTE_MODEL", True):
                try:
                    from openai import OpenAI
                    # Enhanced prompt with stronger JSON guidance
                    enhanced_prompt = f"{prompt}\n\n{json_instructions}"
                    
                    # Accept token via several env/config names
                    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN") or getattr(settings, "HUGGINGFACE_TOKEN", "")
                    if not token:
                        logger.warning("No HF_TOKEN/HUGGINGFACE_TOKEN found; using fallback recommendations")
                        return self._rule_based_recommendations(glucose_data, patterns) if glucose_data else self._fallback_recommendations()
                    
                    client = OpenAI(
                        base_url="https://router.huggingface.co/v1",
                        api_key=token,
                    )
                    
                    # Enhanced system message with stronger JSON emphasis
                    messages = [
                        {"role": "system", "content": "You are a diabetes management assistant that provides personalized, evidence-based recommendations. Be specific, actionable, and concise. Focus on the user's unique patterns and data. Your response MUST be formatted as a proper JSON array of 5 recommendation objects with no text outside the array."},
                        {"role": "user", "content": enhanced_prompt},
                    ]
                    
                    # Prepare completion parameters (lower temp for structure, higher tokens to reduce truncation)
                    completion_params = {
                        "model": "openai/gpt-oss-20b:fireworks-ai",
                        "messages": messages,
                        "temperature": 0.2,
                        "max_tokens": 1536,
                    }
                    
                    # Attempt to add response_format if supported by this client version
                    try:
                        # Add response_format if the client supports it (newer OpenAI SDK versions)
                        completion_params["response_format"] = {"type": "json_object"}
                        logger.info("Using response_format parameter for JSON output")
                    except Exception:
                        logger.info("response_format parameter not supported, proceeding without it")
                    
                    completion = client.chat.completions.create(**completion_params)
                    
                    if completion.choices and completion.choices[0].message.content:
                        ai_response = completion.choices[0].message.content.strip()
                        # Log a trimmed preview of model output to help debug parsing issues
                        try:
                            preview = ai_response[:1000].replace('\n', ' ') if ai_response else ''
                            logger.info(f"Model returned {len(ai_response)} chars; preview: {preview}")
                            
                            # Quick validation - attempt to parse here just for logging
                            try:
                                json.loads(ai_response)
                                logger.info("Model returned valid JSON that parsed successfully")
                            except json.JSONDecodeError as je:
                                logger.warning(f"Model returned invalid JSON: {str(je)}")
                                
                                # Try to clean the response for JSON parsing
                                cleaned_response = re.sub(r'```json|```', '', ai_response).strip()
                                try:
                                    json.loads(cleaned_response)
                                    logger.info("Cleaned response is valid JSON")
                                    ai_response = cleaned_response
                                except json.JSONDecodeError:
                                    logger.warning("Even after cleaning, JSON is invalid")
                                
                        except Exception:
                            logger.info("Model returned content (unable to preview)")
                        
                        # If response looks truncated, try a single continuation attempt
                        try:
                            if self._is_truncated(ai_response) and os.environ.get("AI_RETRY_ON_TRUNCATION", "true").lower() in ("1", "true", "yes"):
                                try:
                                    cont_messages = [
                                        {"role": "system", "content": "Continue the previous reply by finishing the JSON array only. Output valid JSON with no extra text."},
                                        {"role": "user", "content": ai_response + "\n\nFinish and close the JSON array. No commentary."},
                                    ]
                                    continuation = client.chat.completions.create(
                                        model="openai/gpt-oss-20b:fireworks-ai",
                                        messages=cont_messages,
                                        temperature=0.0,
                                        max_tokens=768,
                                    )
                                    if continuation.choices and continuation.choices[0].message.content:
                                        extra = continuation.choices[0].message.content.strip()
                                        logger.info(f"Continuation returned {len(extra)} chars")
                                        candidate = ai_response + extra
                                        repaired = self._repair_json(candidate)
                                        if repaired:
                                            logger.info("Continuation + repair produced valid JSON")
                                            return repaired
                                except Exception as e:
                                    logger.warning(f"Continuation attempt failed: {e}")
                        except Exception:
                            pass

                        # Always return the AI response; robust parsing will handle it
                        return ai_response
                    
                    logger.warning("No choices/content from model API; using fallback")
                    # Generate rule-based recs if we have data; else default placeholder
                    return self._rule_based_recommendations(glucose_data, patterns) if glucose_data else self._fallback_recommendations()
                except Exception as e:
                    logger.error(f"Error with model API: {e}")
                    return self._rule_based_recommendations(glucose_data, patterns) if glucose_data else self._fallback_recommendations()
            else:
                # No local generator on Heroku; use fallback
                return self._rule_based_recommendations(glucose_data, patterns) if glucose_data else self._fallback_recommendations()
        except Exception as e:
            logger.error(f"Error generating AI recommendations: {e}")
            return self._rule_based_recommendations(glucose_data, patterns) if glucose_data else self._fallback_recommendations()

    def _rule_based_recommendations(self, glucose_data: Optional[List[GlucoseReading]], patterns: Optional[Dict[str, Any]]) -> str:
        """Produce simple, tailored JSON recommendations when the remote model isn't available."""
        try:
            vals = [g.value for g in (glucose_data or [])]
            if not vals:
                return self._fallback_recommendations()
            avg = sum(vals) / len(vals)
            highs_pct = 100.0 * len([v for v in vals if v > 180]) / len(vals)
            lows_pct = 100.0 * len([v for v in vals if v < 70]) / len(vals)
            time_in_range = 100.0 * len([v for v in vals if 70 <= v <= 180]) / len(vals)
            cov = patterns.get('variability', {}).get('coefficient_of_variation', 0.0) if isinstance(patterns, dict) else 0.0

            recs: list[dict[str, Any]] = []
            # Highs
            if highs_pct >= 20 or avg > 170:
                recs.append({
                    "title": "Reduce post-meal spikes",
                    "description": f"Average glucose ~{avg:.0f} mg/dL with {highs_pct:.0f}% readings >180 in last 24h. Consider pre-bolus and balancing carbs.",
                    "category": "insulin",
                    "priority": "medium" if highs_pct < 40 else "high",
                    "action": "Pre-bolus 10–15 minutes before higher-carb meals; add protein/fiber.",
                    "timing": "next meal",
                    "confidence": 0.75
                })
            # Lows
            if lows_pct >= 5:
                recs.append({
                    "title": "Address frequent lows",
                    "description": f"About {lows_pct:.0f}% of readings <70 mg/dL. Review correction factor and snacks around activity.",
                    "category": "monitoring",
                    "priority": "high" if lows_pct >= 10 else "medium",
                    "action": "Keep fast carbs available; discuss basal/correction settings with your clinician.",
                    "timing": "today",
                    "confidence": 0.8
                })
            # Variability
            if cov and cov > 36:
                recs.append({
                    "title": "Lower glucose variability",
                    "description": f"Glucose variability (CV) ~{cov:.0f}%. Consistent meal timing and gentle post-meal walks can help.",
                    "category": "lifestyle",
                    "priority": "medium",
                    "action": "Aim for 10–15 minute walk after meals when possible.",
                    "timing": "after meals",
                    "confidence": 0.7
                })
            # General monitoring
            if time_in_range < 70 and len(recs) < 5:
                recs.append({
                    "title": "Increase time in range",
                    "description": f"Time in range ~{time_in_range:.0f}%. Monitor trends 2–3 hours after meals and adjust as needed.",
                    "category": "monitoring",
                    "priority": "medium",
                    "action": "Review CGM 2 hours post-meal and log spikes vs meals.",
                    "timing": "next 24 hours",
                    "confidence": 0.7
                })
            # Ensure 5 items
            while len(recs) < 5:
                recs.append({
                    "title": "Daily check-in",
                    "description": "Briefly review your glucose trend and note any patterns tied to meals, stress, or activity.",
                    "category": "general",
                    "priority": "low",
                    "action": "Open your trends view and add a short note.",
                    "timing": "tonight",
                    "confidence": 0.6
                })

            return json.dumps(recs)
        except Exception:
            return self._fallback_recommendations()

    def _fallback_recommendations(self) -> str:
        return """
        [
          {
            "title": "Track glucose patterns after meals",
            "description": "Review 3 hours after meals for spikes above 180 mg/dL and note foods causing larger rises.",
            "category": "monitoring",
            "priority": "medium",
            "action": "Check CGM 2 hours post-meal and log spikes",
            "timing": null,
            "confidence": 0.7
          },
          {
            "title": "Consider a short pre-bolus for high-carb meals",
            "description": "Taking insulin 15–20 minutes before higher-carb meals can reduce post-meal spikes.",
            "category": "insulin",
            "priority": "medium",
            "action": "Pre-bolus 15 minutes before >40g carb meals if safe",
            "timing": null,
            "confidence": 0.7
          },
          {
            "title": "Balance carbs with protein/fiber",
            "description": "Add protein or fiber to meals to slow glucose rise and reduce spikes.",
            "category": "nutrition",
            "priority": "low",
            "action": "Add protein/fiber to next meal",
            "timing": null,
            "confidence": 0.7
          },
          {
            "title": "Light post-meal activity",
            "description": "A 10–15 minute walk within 30 minutes after eating can lower post-meal glucose peaks.",
            "category": "activity",
            "priority": "medium",
            "action": "Walk 10–15 minutes after your next meal",
            "timing": null,
            "confidence": 0.7
          },
          {
            "title": "Review correction factor with your clinician",
            "description": "If corrections underperform or overshoot, re-evaluate insulin sensitivity settings.",
            "category": "insulin",
            "priority": "low",
            "action": "Schedule a settings review",
            "timing": null,
            "confidence": 0.6
          }
        ]
        """

    # -------------------- JSON repair and parsing utilities --------------------
    def _strip_code_fences(self, text: str) -> str:
        try:
            return re.sub(r"```json|```", "", text or "").strip()
        except Exception:
            return text or ""

    def _is_truncated(self, text: str) -> bool:
        """Heuristically detect if a JSON array string looks truncated (unbalanced brackets or open string)."""
        if not text:
            return False
        s = self._strip_code_fences(text)
        in_str = False
        escape = False
        stack = []  # track closing brackets expected
        for ch in s:
            if in_str:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == '"':
                    in_str = False
                continue
            else:
                if ch == '"':
                    in_str = True
                elif ch == '{':
                    stack.append('}')
                elif ch == '[':
                    stack.append(']')
                elif ch in ('}', ']'):
                    if stack and stack[-1] == ch:
                        stack.pop()
        # Truncated if still inside string or unclosed brackets remain
        if in_str or len(stack) > 0:
            return True
        # Also consider truncated if it ends with a comma or colon
        tail = s.rstrip()[-2:]
        return tail.endswith(',') or tail.endswith(':')

    def _repair_json(self, text: str) -> Optional[str]:
        """Attempt to repair common JSON issues and return a parseable JSON string if possible."""
        if not text:
            return None
        s = self._strip_code_fences(text)
        # If there's extra preface/suffix, try to isolate the outermost array
        start = s.find('[')
        if start != -1:
            s = s[start:]
        # Remove trailing junk after last likely bracket
        last_bracket = max(s.rfind(']'), s.rfind('}'))
        if last_bracket != -1:
            s = s[: last_bracket + 1]
        # Fix trailing commas
        s = re.sub(r",(\s*[}\]])", r"\1", s)
        # State-machine to balance strings and brackets
        in_str = False
        escape = False
        stack = []
        out = []
        for ch in s:
            out.append(ch)
            if in_str:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == '"':
                    in_str = False
                continue
            else:
                if ch == '"':
                    in_str = True
                elif ch == '{':
                    stack.append('}')
                elif ch == '[':
                    stack.append(']')
                elif ch in ('}', ']'):
                    if stack and stack[-1] == ch:
                        stack.pop()
        # Close open string
        if in_str:
            out.append('"')
            in_str = False
        # Close any remaining brackets
        while stack:
            out.append(stack.pop())
        candidate = ''.join(out)
        # Final trailing-comma cleanup after balancing
        candidate = re.sub(r",(\s*[}\]])", r"\1", candidate)
        # If it's an object, wrap in array to fit expected schema
        cand_strip = candidate.lstrip()
        if cand_strip.startswith('{') and not cand_strip.startswith('['):
            candidate = '[' + candidate + ']'
        try:
            json.loads(candidate)
            return candidate
        except Exception:
            return None

    def _extract_json_array(self, text: str) -> Optional[str]:
        """Extract the first top-level JSON array substring using bracket matching."""
        if not text:
            return None
        s = self._strip_code_fences(text)
        start = s.find('[')
        if start == -1:
            return None
        in_str = False
        escape = False
        depth = 0
        for i in range(start, len(s)):
            ch = s[i]
            if in_str:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == '[':
                    depth += 1
                elif ch == ']':
                    depth -= 1
                    if depth == 0:
                        return s[start : i + 1]
        # If unbalanced, return from start to end; caller may repair
        return s[start:]

    def _split_json_array_objects(self, array_text: str) -> List[str]:
        """Split a JSON array into object substrings using bracket and string awareness."""
        result: List[str] = []
        if not array_text:
            return result
        s = array_text.strip()
        if not s.startswith('['):
            return result
        i = 1  # skip initial '['
        in_str = False
        escape = False
        obj_depth = 0
        start_idx = -1
        while i < len(s):
            ch = s[i]
            if in_str:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == '{':
                    if obj_depth == 0:
                        start_idx = i
                    obj_depth += 1
                elif ch == '}':
                    obj_depth -= 1
                    if obj_depth == 0 and start_idx != -1:
                        result.append(s[start_idx : i + 1])
                        start_idx = -1
                # commas and spaces between objects are ignored
            i += 1
        return result

    def _process_recommendations(self, ai_text: str, user_id: int) -> List[Dict[str, Any]]:
        recommendations: List[Dict[str, Any]] = []
        # Enhanced logging to better diagnose parsing issues
        try:
            preview = ai_text[:500].replace('\n', ' ') if ai_text else '<empty>'
            logger.info(f"Processing recommendations from text ({len(ai_text)} chars): {preview}...")
        except Exception:
            logger.info("Processing recommendations (preview unavailable)")

        # Method 1: Direct parse after repair
        try:
            repaired = self._repair_json(ai_text)
            if repaired:
                parsed = json.loads(repaired)
                if isinstance(parsed, list) and all(isinstance(item, dict) for item in parsed):
                    logger.info(f"Successfully parsed repaired JSON array with {len(parsed)} items")
                    for item in parsed:
                        rec = {
                            'title': item.get('title', ''),
                            'description': item.get('description', ''),
                            'category': item.get('category', 'general'),
                            'priority': item.get('priority', 'medium'),
                            'confidence': float(item.get('confidence', 0.8)),
                            'action': item.get('action', ''),
                            'timing': item.get('timing', ''),
                            'context': self._attach_examples_and_graph(item),
                        }
                        recommendations.append(rec)
                    return recommendations[:5]
        except Exception as e:
            logger.info(f"Repaired JSON parsing failed: {str(e)}")

        # Method 2: Extract array, then split into objects with state-aware parser
        try:
            array_str = self._extract_json_array(ai_text)
            if array_str:
                repaired_array = self._repair_json(array_str) or array_str
                objects = self._split_json_array_objects(repaired_array)
                logger.info(f"Split array into {len(objects)} potential objects (state-aware)")
                for i, obj_str in enumerate(objects):
                    try:
                        repaired_obj = self._repair_json(obj_str) or obj_str
                        item = json.loads(repaired_obj)
                        rec = {
                            'title': item.get('title', ''),
                            'description': item.get('description', ''),
                            'category': item.get('category', 'general'),
                            'priority': item.get('priority', 'medium'),
                            'confidence': float(item.get('confidence', 0.8)),
                            'action': item.get('action', ''),
                            'timing': item.get('timing', ''),
                            'context': self._attach_examples_and_graph(item),
                        }
                        recommendations.append(rec)
                    except Exception as e:
                        logger.info(f"Failed to parse object {i+1}: {str(e)}")
                        continue
                if recommendations:
                    logger.info(f"Successfully extracted {len(recommendations)} recommendations using state-aware parsing")
                    return recommendations[:5]
        except Exception as e:
            logger.info(f"State-aware array parsing failed: {str(e)}")

        # Method 3: Regex object extraction as last resort before text heuristics
        try:
            json_objects = re.findall(r'\{[\s\S]*?\}', ai_text)
            logger.info(f"Found {len(json_objects)} potential JSON objects using regex")
            for i, obj_str in enumerate(json_objects):
                try:
                    repaired_obj = self._repair_json(obj_str) or obj_str
                    item = json.loads(repaired_obj)
                    if not ('title' in item or 'description' in item):
                        continue
                    rec = {
                        'title': item.get('title', ''),
                        'description': item.get('description', ''),
                        'category': item.get('category', 'general'),
                        'priority': item.get('priority', 'medium'),
                        'confidence': float(item.get('confidence', 0.8)),
                        'action': item.get('action', ''),
                        'timing': item.get('timing', ''),
                        'context': self._attach_examples_and_graph(item),
                    }
                    recommendations.append(rec)
                except Exception:
                    continue
            if recommendations:
                logger.info(f"Successfully extracted {len(recommendations)} recommendations using regex objects")
                return recommendations[:5]
        except Exception as e:
            logger.info(f"Regex JSON extraction failed: {str(e)}")

        # Method 4: Numbered text fallback
        try:
            numbered_items = re.split(r'\n(?=\d+[\.)] )', ai_text.strip())
            logger.info(f"Found {len(numbered_items)} potential numbered items")
            
            if len(numbered_items) > 1:
                for i, item in enumerate(numbered_items):
                    item = item.strip()
                    if not item:
                        continue
                    try:
                        title = re.search(r'Title:?\s*(.*)', item, re.IGNORECASE)
                        description = re.search(r'Description:?\s*([\s\S]*?)(?:\nCategory:|\nPriority:|\nAction:|\nTiming:|$)', item, re.IGNORECASE)
                        category = re.search(r'Category:?\s*(.*)', item, re.IGNORECASE)
                        priority = re.search(r'Priority:?\s*(.*)', item, re.IGNORECASE)
                        action = re.search(r'Action:?\s*(.*)', item, re.IGNORECASE)
                        timing = re.search(r'Timing:?\s*(.*)', item, re.IGNORECASE)
                        
                        rec = {
                            'title': title.group(1).strip() if title else '',
                            'description': description.group(1).strip() if description else '',
                            'category': (category.group(1).strip().lower() if category else 'general'),
                            'priority': (priority.group(1).strip().lower() if priority else 'medium'),
                            'confidence': 0.8,
                            'action': action.group(1).strip() if action else '',
                            'timing': timing.group(1).strip() if timing else '',
                            'context': self._attach_examples_and_graph({
                                'title': title.group(1).strip() if title else '',
                                'description': description.group(1).strip() if description else '',
                                'category': (category.group(1).strip().lower() if category else 'general'),
                            }),
                        }
                        if rec['title'] or rec['description']:
                            recommendations.append(rec)
                            logger.info(f"Added item {i+1} from text format with title: {rec['title'][:30]}...")
                    except Exception as e:
                        logger.info(f"Failed to parse numbered item {i+1}: {str(e)}")
                        continue
                        
                if recommendations:
                    logger.info(f"Successfully extracted {len(recommendations)} recommendations using method 4")
                    return recommendations[:5]
        except Exception as e:
            logger.info(f"Numbered text parsing failed: {str(e)}")

        # Method 5: Markdown-style fallback
        try:
            items = re.split(r'\n---+\n|(?=\*\*\d+\. Title:)', ai_text)
            logger.info(f"Found {len(items)} potential markdown items")
            
            for i, item in enumerate(items):
                if not item.strip():
                    continue
                try:
                    title = re.search(r'\*\*\d+\. Title:\*\*\s*(.*)', item)
                    description = re.search(r'\*\*Description:\*\*\s*([\s\S]*?)\n\*\*Category:', item)
                    category = re.search(r'\*\*Category:\*\*\s*(.*)', item)
                    priority = re.search(r'\*\*Priority:\*\*\s*(.*)', item)
                    action = re.search(r'\*\*Action:\*\*\s*(.*)', item)
                    timing = re.search(r'\*\*Timing:\*\*\s*(.*)', item)
                    
                    rec = {
                        'title': title.group(1).strip() if title else '',
                        'description': description.group(1).strip() if description else '',
                        'category': (category.group(1).strip().lower() if category else 'general'),
                        'priority': (priority.group(1).strip().lower() if priority else 'medium'),
                        'confidence': 0.8,
                        'action': action.group(1).strip() if action else '',
                        'timing': timing.group(1).strip() if timing else '',
                        'context': self._attach_examples_and_graph({
                            'title': title.group(1).strip() if title else '',
                            'description': description.group(1).strip() if description else '',
                            'category': (category.group(1).strip().lower() if category else 'general'),
                        }),
                    }
                    if rec['title'] or rec['description']:
                        recommendations.append(rec)
                        logger.info(f"Added item {i+1} from markdown format with title: {rec['title'][:30]}...")
                except Exception as e:
                    logger.info(f"Failed to parse markdown item {i+1}: {str(e)}")
                    continue
                    
            if recommendations:
                logger.info(f"Successfully extracted {len(recommendations)} recommendations using method 5")
                return recommendations[:5]
        except Exception as e:
            logger.info(f"Markdown parsing failed: {str(e)}")
        
        # Method 6: Last resort - look for title-description pairs anywhere in text
        try:
            title_matches = re.findall(r'(?:^|\n)(?:Title:?\s*|Recommendation\s*\d+:?\s*)(.*?)(?:\n|$)', ai_text, re.IGNORECASE)
            logger.info(f"Found {len(title_matches)} potential title matches in raw text")
            
            if title_matches and len(title_matches) <= 10:  # Reasonable number of recommendations
                for i, title in enumerate(title_matches):
                    title = title.strip()
                    if not title or len(title) < 5 or len(title) > 100:  # Skip likely invalid titles
                        continue
                        
                    # Try to find a description near this title
                    title_pos = ai_text.find(title)
                    if title_pos >= 0:
                        # Look for a description in the next 500 chars after the title
                        next_chunk = ai_text[title_pos:title_pos+500]
                        desc_match = re.search(r'(?:Description:?\s*)(.*?)(?:\n|$)', next_chunk, re.IGNORECASE)
                        description = desc_match.group(1).strip() if desc_match else ""
                        
                        if not description and len(next_chunk) > 50:
                            # If no explicit description, take the next paragraph
                            lines = next_chunk.split('\n')
                            if len(lines) > 1:
                                description = lines[1].strip()
                        
                        rec = {
                            'title': title,
                            'description': description,
                            'category': 'general',
                            'priority': 'medium',
                            'confidence': 0.7,
                            'action': '',
                            'timing': '',
                            'context': self._attach_examples_and_graph({
                                'title': title,
                                'description': description,
                                'category': 'general',
                            }),
                        }
                        recommendations.append(rec)
                        logger.info(f"Added item {i+1} from title-description with title: {title[:30]}...")
                
                if recommendations:
                    logger.info(f"Successfully extracted {len(recommendations)} recommendations using method 6")
                    return recommendations[:5]
        except Exception as e:
            logger.info(f"Title-description parsing failed: {str(e)}")

        # Final fallback
        try:
            short = ai_text[:1000].replace('\n', ' ') if ai_text else '<empty>'
            logger.warning(f"Failed to parse AI output with all methods; using fallback recommendations. AI preview: {short}")
        except Exception:
            logger.warning("Failed to parse AI output; using fallback recommendations (preview unavailable)")
        
        # Try to extract at least something from the AI response even if it's not fully formatted
        if ai_text and len(ai_text) > 100:
            try:
                # If the text is substantial but couldn't be parsed in standard formats,
                # create at least one recommendation from it to show something from the AI
                paragraphs = [p for p in ai_text.split('\n\n') if p.strip()]
                if paragraphs:
                    first_para = paragraphs[0].strip()
                    desc_paras = ' '.join([p.strip() for p in paragraphs[1:3]]) if len(paragraphs) > 1 else ""
                    
                    # Try to find a sensible title in the first paragraph
                    title = first_para.split('.')[0] if '.' in first_para else first_para
                    if len(title) > 80:  # Too long for a title
                        title = ' '.join(title.split()[:10]) + '...'
                        
                    recommendations.append({
                        'title': title,
                        'description': desc_paras or "Review this AI analysis of your glucose patterns.",
                        'category': 'general',
                        'priority': 'medium',
                        'confidence': 0.6,
                        'action': 'Review the insights provided',
                        'timing': '',
                        'context': self._attach_examples_and_graph({
                            'title': title,
                            'description': desc_paras,
                            'category': 'general',
                            'ai_raw_text': ai_text[:2000] if len(ai_text) > 2000 else ai_text,
                        }),
                    })
                    logger.info("Created one recommendation from unstructured AI text")
                    return recommendations
            except Exception as e:
                logger.info(f"Failed to create recommendation from unstructured text: {str(e)}")
        
        # Ultimate fallback - use hardcoded recommendations
        return self._process_recommendations(self._fallback_recommendations(), user_id)

    def _attach_examples_and_graph(self, rec: dict) -> dict:
        now = datetime.utcnow()
        recommendation_id = str(uuid.uuid4())
        supporting_data_points = [
            {
                'timestamp': (now - timedelta(hours=3)).isoformat(),
                'value': 250,
                'event_type': rec.get('category', 'general'),
                'note': 'Example spike before meal',
            },
            {
                'timestamp': (now - timedelta(hours=2, minutes=30)).isoformat(),
                'value': 180,
                'event_type': rec.get('category', 'general'),
                'note': 'Glucose after insulin',
            },
        ]
        example_event = {
            'timestamp': (now - timedelta(hours=random.randint(1, 24))).isoformat(),
            'value': random.randint(60, 300),
            'event_type': rec.get('category', 'general'),
            'note': f"Example event for {rec.get('category', 'general')}",
        }
        graph_data = [
            {
                'timestamp': (now - timedelta(hours=12) + timedelta(minutes=15 * i)).isoformat(),
                'value': 100 + 40 * math.sin(i / 4.0) + random.randint(-10, 10),
            }
            for i in range(48)
        ]
        context = rec.get('context', {}) if 'context' in rec else {}

        # Timeframe extraction
        timeframe = None
        if 'start' in rec and 'end' in rec:
            try:
                start = str(rec['start']); end = str(rec['end'])
                datetime.fromisoformat(start); datetime.fromisoformat(end)
                timeframe = {'start': start, 'end': end}
            except Exception:
                pass
        elif 'timeframe' in rec:
            tf = rec['timeframe']
            if isinstance(tf, dict) and 'start' in tf and 'end' in tf:
                timeframe = {'start': str(tf['start']), 'end': str(tf['end'])}
            elif isinstance(tf, str):
                try:
                    m = re.match(r'last (\d+) hours?', tf.lower())
                    if m:
                        hours = int(m.group(1))
                        timeframe = {'start': (now - timedelta(hours=hours)).isoformat(), 'end': now.isoformat()}
                    else:
                        parts = tf.split('/')
                        if len(parts) == 2:
                            datetime.fromisoformat(parts[0]); datetime.fromisoformat(parts[1])
                            timeframe = {'start': parts[0], 'end': parts[1]}
                except Exception:
                    pass
        elif 'timing' in rec and isinstance(rec['timing'], str):
            m = re.match(r'last (\d+) hours?', rec['timing'].lower())
            if m:
                hours = int(m.group(1))
                timeframe = {'start': (now - timedelta(hours=hours)).isoformat(), 'end': now.isoformat()}
        if not timeframe and rec.get('category', '').lower() in ['glucose', 'insulin', 'nutrition', 'exercise', 'monitoring']:
            timeframe = {'start': (now - timedelta(hours=3)).isoformat(), 'end': now.isoformat()}
        if timeframe:
            context['timeframe'] = timeframe

        context.update(
            {
                'generated_at': now.isoformat(),
                'ai_model': getattr(self, 'model_name', 'unknown'),
                'recommendation_id': recommendation_id,
                'example_event': example_event,
                'graph_data': graph_data,
                'supporting_data_points': supporting_data_points,
            }
        )
        return context

    def _calculate_suggested_time(self, recommendation_data: dict, now: datetime) -> datetime:
        category = recommendation_data.get('category', '').lower()
        desc = recommendation_data.get('description', '').lower()
        if 'insulin' in category and 'pre-meal' in desc:
            hour = now.hour
            if 5 <= hour < 10:
                return now + timedelta(hours=1)
            elif 10 <= hour < 14:
                return now + timedelta(hours=2)
            elif 16 <= hour < 20:
                return now + timedelta(hours=1)
            else:
                return now + timedelta(hours=3)
        elif 'activity' in category or 'exercise' in category:
            return (now + timedelta(hours=3)) if now.hour < 16 else datetime(now.year, now.month, now.day, 10, 0) + timedelta(days=1)
        elif 'sleep' in category:
            return datetime(now.year, now.month, now.day, 21, 0)
        elif 'monitoring' in category:
            return now + timedelta(hours=1)
        return now + timedelta(hours=3)

    # -------------------- Parsing helpers --------------------
    def _parse_recommendation(self, rec_text: str, user_id: int) -> Optional[Dict[str, Any]]:
        if not rec_text or len(rec_text.strip()) < 10:
            return None
        text = rec_text
        if text[0].isdigit():
            text = text[text.find('.') + 1:].strip() if '.' in text else text[1:].strip()
        lines = text.split('\n')
        result: Dict[str, Any] = {
            'description': text,
            'title': '',
            'category': 'general',
            'priority': 'medium',
            'confidence': 0.8,
            'action': '',
            'context': {'generated_at': datetime.utcnow().isoformat(), 'ai_model': self.model_name},
        }
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.lower().startswith('title:'):
                result['title'] = line[len('title:'):].strip()
            elif line.lower().startswith('category:'):
                category = line[len('category:'):].strip().lower()
                result['category'] = category if category in ['insulin', 'nutrition', 'activity', 'monitoring', 'sleep', 'stress', 'general'] else self._categorize_recommendation(category)
            elif line.lower().startswith('priority:'):
                priority = line[len('priority:'):].strip().lower()
                result['priority'] = priority if priority in ['high', 'medium', 'low'] else self._prioritize_recommendation(priority)
            elif line.lower().startswith('action:'):
                result['action'] = line[len('action:'):].strip()
            elif line.lower().startswith('timing:'):
                result['timing'] = line[len('timing:'):].strip()
        if not result['title'] and lines:
            result['title'] = lines[0].split('.')[0][:60] + ('...' if len(lines[0].split('.')[0]) > 60 else '')
        if result['category'] == 'general' and not any(k in result for k in ['action', 'timing']):
            result['category'] = self._categorize_recommendation(text)
            result['priority'] = self._prioritize_recommendation(text)
        return result

    def _categorize_recommendation(self, text: str) -> str:
        text_lower = text.lower()
        if any(word in text_lower for word in ['insulin', 'dose', 'bolus', 'correction']):
            return 'insulin'
        elif any(word in text_lower for word in ['meal', 'food', 'carb', 'eat']):
            return 'nutrition'
        elif any(word in text_lower for word in ['exercise', 'activity', 'walk']):
            return 'activity'
        elif any(word in text_lower for word in ['timing', 'time', 'schedule']):
            return 'timing'
        elif any(word in text_lower for word in ['monitor', 'check', 'test']):
            return 'monitoring'
        else:
            return 'general'

    def _prioritize_recommendation(self, text: str) -> str:
        text_lower = text.lower()
        if any(word in text_lower for word in ['urgent', 'immediate', 'dangerous', 'severe']):
            return 'high'
        elif any(word in text_lower for word in ['important', 'significant', 'consider']):
            return 'medium'
        else:
            return 'low'

    # Utility to keep API compatibility if needed
    def _recommendation_to_dict(self, recommendation: Recommendation) -> Dict[str, Any]:
        return {
            'id': recommendation.id,
            'title': recommendation.title,
            'description': recommendation.description,
            'category': recommendation.category,
            'priority': recommendation.priority,
            'confidence_score': recommendation.confidence_score,
            'created_at': recommendation.created_at.isoformat(),
            'context': json.loads(recommendation.context_data) if recommendation.context_data else {},
        }
