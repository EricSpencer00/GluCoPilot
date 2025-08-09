import statistics
from datetime import datetime, timedelta
from pydexcom import Dexcom

def get_long_term_trends(dexcom, days=30, low_mgdl=70, high_mgdl=180):
    # Fetch up to 30 days of readings (max_count is 288 per day)
    readings = dexcom.get_glucose_readings(minutes=days*1440, max_count=days*288)
    if not readings:
        return {}

    # Organize readings by week
    readings_by_week = {}
    for r in readings:
        week = r.datetime.isocalendar()[1]
        readings_by_week.setdefault(week, []).append(r)

    def compute_stats(readings):
        values = [r.value for r in readings]
        if not values:
            return {}
        in_range = [v for v in values if low_mgdl <= v <= high_mgdl]
        return {
            "average": round(statistics.mean(values), 2),
            "median": round(statistics.median(values), 2),
            "stdev": round(statistics.stdev(values), 2) if len(values) > 1 else 0,
            "min": min(values),
            "max": max(values),
            "range": round(max(values) - min(values), 2),
            "time_in_range_pct": round(len(in_range) / len(values) * 100, 2),
            "coef_variation_pct": round((statistics.stdev(values) / statistics.mean(values)) * 100, 2) if len(values) > 1 else 0,
            "glycemic_variability_index": round((statistics.stdev(values) / statistics.mean(values)) * 100, 2) if len(values) > 1 else 0,
            "estimated_a1c": round((statistics.mean(values) + 46.7) / 28.7, 2)
        }

    # Compute stats for each week and overall
    trends = {
        "overall": compute_stats(readings),
        "weeks": {}
    }
    for week, week_readings in readings_by_week.items():
        trends["weeks"][f"week_{week}"] = compute_stats(week_readings)

    return trends
