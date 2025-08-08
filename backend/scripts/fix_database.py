"""
Script to fix the database schema, particularly         if "insulin_sensitivity_factor" not in columns:
            logger.info("Adding insulin_sensitivity_factor column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN insulin_sensitivity_factor INTEGER")
        
        # Add Dexcom integration columns
        if "dexcom_username" not in columns:
            logger.info("Adding dexcom_username column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN dexcom_username TEXT")
        
        if "dexcom_password" not in columns:
            logger.info("Adding dexcom_password column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN dexcom_password TEXT")
        
        if "dexcom_ous" not in columns:
            logger.info("Adding dexcom_ous column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN dexcom_ous INTEGER DEFAULT 0")
        
        conn.commit()
        logger.info("Database schema fixed successfully") missing columns to the users table.
"""
import os
import sys
import sqlite3

# Database path
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "glucopilot.db")

def fix_database():
    """Fix the database schema by adding missing columns"""
    print("Starting database schema fix...")
    
    # Connect to the database
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Check if first_name column exists
        cursor.execute("PRAGMA table_info(users)")
        columns = [col[1] for col in cursor.fetchall()]
        
        # Add missing columns
        if "first_name" not in columns:
            print("Adding first_name column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN first_name TEXT")
        
        if "last_name" not in columns:
            print("Adding last_name column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN last_name TEXT")
        
        if "is_verified" not in columns:
            print("Adding is_verified column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0")
        
        if "last_login" not in columns:
            print("Adding last_login column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN last_login TIMESTAMP")
        
        if "target_glucose_min" not in columns:
            print("Adding target_glucose_min column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN target_glucose_min INTEGER DEFAULT 70")
        
        if "target_glucose_max" not in columns:
            print("Adding target_glucose_max column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN target_glucose_max INTEGER DEFAULT 180")
        
        if "insulin_carb_ratio" not in columns:
            print("Adding insulin_carb_ratio column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN insulin_carb_ratio INTEGER")
        
        if "insulin_sensitivity_factor" not in columns:
            print("Adding insulin_sensitivity_factor column to users table")
            cursor.execute("ALTER TABLE users ADD COLUMN insulin_sensitivity_factor INTEGER")
        
        conn.commit()
        print("Database schema fixed successfully")
        
    except Exception as e:
        print(f"Error fixing database schema: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    fix_database()
