from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    """Base user schema"""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    first_name: Optional[str] = Field(None, max_length=50)
    last_name: Optional[str] = Field(None, max_length=50)

class UserCreate(UserBase):
    """User creation schema"""
    password: str = Field(..., min_length=8)
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v

class UserLogin(BaseModel):
    """User login schema"""
    username: str
    password: str

class UserResponse(UserBase):
    """User response schema"""
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login: Optional[datetime]
    
    # Diabetes profile
    target_glucose_min: Optional[int]
    target_glucose_max: Optional[int]
    insulin_carb_ratio: Optional[int]
    insulin_sensitivity_factor: Optional[int]
    
    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    """User update schema (all editable fields)"""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    target_glucose_min: Optional[int] = Field(None, ge=50, le=120) # unsure if we can increase this
    target_glucose_max: Optional[int] = Field(None, ge=120, le=300) # unsure if this is a good limit or minima
    insulin_carb_ratio: Optional[int] = Field(None, ge=5, le=50)
    insulin_sensitivity_factor: Optional[int] = Field(None, ge=20, le=200)
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    birthdate: Optional[datetime] = None
    gender: Optional[str] = None
    diabetes_type: Optional[int] = Field(None, ge=1, le=2)
    diagnosis_date: Optional[datetime] = None
    dexcom_username: Optional[str] = None
    dexcom_ous: Optional[bool] = None
    myfitnesspal_username: Optional[str] = None
    apple_health_authorized: Optional[bool] = None
    google_fit_authorized: Optional[bool] = None
    fitbit_authorized: Optional[bool] = None
    notification_preferences: Optional[dict] = None
    privacy_preferences: Optional[dict] = None

class Token(BaseModel):
    """JWT token schema"""
    access_token: str
    token_type: str
    expires_in: int

class TokenData(BaseModel):
    """Token data schema"""
    username: Optional[str] = None
