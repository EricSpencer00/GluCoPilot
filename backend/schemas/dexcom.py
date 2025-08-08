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
