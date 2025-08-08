-- Add missing fields to the users table
ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN last_login DATETIME;
ALTER TABLE users ADD COLUMN target_glucose_min INTEGER;
ALTER TABLE users ADD COLUMN target_glucose_max INTEGER;
ALTER TABLE users ADD COLUMN insulin_carb_ratio INTEGER;
ALTER TABLE users ADD COLUMN insulin_sensitivity_factor INTEGER;
