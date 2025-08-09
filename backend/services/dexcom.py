from typing import List, Optional
from datetime import datetime, timedelta
import asyncio
from sqlalchemy.orm import Session
from pydexcom import Dexcom

from models.user import User
from models.glucose import GlucoseReading
from core.config import settings
from utils.logging import get_logger
from utils.encryption import decrypt_password

logger = get_logger(__name__)

class DexcomService:
    """Service for Dexcom CGM data integration"""
    
    def __init__(self):
        self.client = None
    
    async def _get_dexcom_client(self, user: User) -> Dexcom:
        """Initialize Dexcom client for user"""
        if not user.dexcom_username or not user.dexcom_password:
            raise ValueError("Dexcom credentials not configured")
        
        # Decrypt password
        decrypted_password = decrypt_password(user.dexcom_password)
        
        return Dexcom(
            username=user.dexcom_username,
            password=decrypted_password,
            ous=user.dexcom_ous or False
        )
    
    async def sync_glucose_data(self, user: User, db: Session, hours: int = 24) -> List[GlucoseReading]:
        """Sync glucose data from Dexcom for the specified time period"""
        logger.info(f"Starting Dexcom sync for user {user.id}, last {hours} hours")
        
        try:
            # Get Dexcom client
            dexcom = await self._get_dexcom_client(user)
            
            # Get the most recent reading timestamp from database
            latest_reading = db.query(GlucoseReading)\
                .filter(GlucoseReading.user_id == user.id)\
                .filter(GlucoseReading.source == "dexcom")\
                .order_by(GlucoseReading.timestamp.desc())\
                .first()
            
            # Determine sync period
            if latest_reading:
                start_time = latest_reading.timestamp
                logger.info(f"Syncing from last reading: {start_time}")
            else:
                start_time = datetime.utcnow() - timedelta(hours=hours)
                logger.info(f"First sync - fetching last {hours} hours")
            
            end_time = datetime.utcnow()
            
            # Fetch glucose readings from Dexcom
            minutes = int(max(1, min(1440, (end_time - start_time).total_seconds() / 60)))
            bg_readings = dexcom.get_glucose_readings(minutes=minutes)
            
            new_readings = []
            
            for bg in bg_readings:
                # Check if reading already exists
                existing = db.query(GlucoseReading)\
                    .filter(GlucoseReading.user_id == user.id)\
                    .filter(GlucoseReading.timestamp == bg.time)\
                    .filter(GlucoseReading.source == "dexcom")\
                    .first()
                
                if not existing:
                    reading = GlucoseReading(
                        user_id=user.id,
                        value=bg.value,
                        trend=self._map_dexcom_trend(bg.trend),
                        trend_rate=self._calculate_trend_rate(bg.trend),
                        timestamp=bg.time,
                        source="dexcom",
                        quality="high"
                    )
                    
                    # Set alert flags
                    reading.is_urgent_low = bg.value < 54
                    reading.is_low_alert = bg.value < 70
                    reading.is_high_alert = bg.value > 250
                    
                    db.add(reading)
                    new_readings.append(reading)
            
            # Commit all new readings
            if new_readings:
                db.commit()
                logger.info(f"Added {len(new_readings)} new glucose readings")
            
            return new_readings
        
        except Exception as e:
            logger.error(f"Dexcom sync error: {str(e)}")
            db.rollback()
            raise
    
    def _map_dexcom_trend(self, dexcom_trend) -> str:
        """Map Dexcom trend to standardized trend string"""
        trend_mapping = {
            1: "rising_rapidly",    # ↑↑
            2: "rising",           # ↑
            3: "rising_slightly",  # ↗
            4: "stable",           # →
            5: "falling_slightly", # ↘
            6: "falling",          # ↓
            7: "falling_rapidly",  # ↓↓
            8: "unknown",          # ?
            9: "not_computable"    # NC
        }
        
        return trend_mapping.get(dexcom_trend, "unknown")
    
    def _calculate_trend_rate(self, dexcom_trend) -> Optional[float]:
        """Calculate approximate trend rate in mg/dL per minute"""
        # Approximate rates based on Dexcom trend arrows
        trend_rates = {
            1: 3.0,   # Rising rapidly (>3 mg/dL/min)
            2: 2.0,   # Rising (2-3 mg/dL/min)
            3: 1.0,   # Rising slightly (1-2 mg/dL/min)
            4: 0.0,   # Stable (-1 to 1 mg/dL/min)
            5: -1.0,  # Falling slightly (-2 to -1 mg/dL/min)
            6: -2.0,  # Falling (-3 to -2 mg/dL/min)
            7: -3.0,  # Falling rapidly (<-3 mg/dL/min)
        }
        
        return trend_rates.get(dexcom_trend)
    
    async def get_current_glucose(self, user: User) -> Optional[GlucoseReading]:
        """Get the most current glucose reading from Dexcom"""
        try:
            dexcom = await self._get_dexcom_client(user)
            current_bg = dexcom.get_current_glucose_reading()
            
            if current_bg:
                return GlucoseReading(
                    user_id=user.id,
                    value=current_bg.value,
                    trend=self._map_dexcom_trend(current_bg.trend),
                    trend_rate=self._calculate_trend_rate(current_bg.trend),
                    timestamp=current_bg.time,
                    source="dexcom",
                    quality="high",
                    is_urgent_low=current_bg.value < 54,
                    is_low_alert=current_bg.value < 70,
                    is_high_alert=current_bg.value > 250
                )
            
            return None
        
        except Exception as e:
            logger.error(f"Error getting current glucose: {str(e)}")
            return None
