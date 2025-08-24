from pydantic import BaseModel, Field
from typing import Optional

class DexcomCredentials(BaseModel):
    """Dexcom credentials schema"""
    username: str
    password: str
    ous: Optional[bool] = False

class DexcomResponse(BaseModel):
    """Dexcom response schema"""
    success: bool
    message: str

class DexcomLoginRequest(BaseModel):
    """Schema for Dexcom login request"""
    username: str
    password: str

class DexcomLoginResponse(BaseModel):
    """Schema for Dexcom login response"""
    message: str

class DexcomTrendsRequest(BaseModel):
    """Payload for stateless Dexcom trends request"""
    username: str
    password: str
    ous: Optional[bool] = False
    days: int = 30
    # ISO date strings YYYY-MM-DD
    startDate: Optional[str] = None
    endDate: Optional[str] = None
