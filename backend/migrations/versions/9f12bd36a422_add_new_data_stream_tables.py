"""Add new data stream tables

Revision ID: 9f12bd36a422
Revises: 20250808_merge_heads
Create Date: 2025-08-09 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '9f12bd36a422'
down_revision = '20250808_merge_heads'
branch_labels = None
depends_on = None


def upgrade():
    # Update user table with new fields
    op.add_column('users', sa.Column('myfitnesspal_username', sa.String(), nullable=True))
    op.add_column('users', sa.Column('myfitnesspal_password', sa.String(), nullable=True))
    op.add_column('users', sa.Column('apple_health_authorized', sa.Boolean(), default=False))
    op.add_column('users', sa.Column('google_fit_authorized', sa.Boolean(), default=False))
    op.add_column('users', sa.Column('fitbit_authorized', sa.Boolean(), default=False))
    op.add_column('users', sa.Column('third_party_tokens', postgresql.JSON(), nullable=True))
    op.add_column('users', sa.Column('height_cm', sa.Float(), nullable=True))
    op.add_column('users', sa.Column('weight_kg', sa.Float(), nullable=True))
    op.add_column('users', sa.Column('birthdate', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('gender', sa.String(), nullable=True))
    op.add_column('users', sa.Column('diabetes_type', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('diagnosis_date', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('notification_preferences', postgresql.JSON(), nullable=True))
    op.add_column('users', sa.Column('privacy_preferences', postgresql.JSON(), nullable=True))
    op.add_column('users', sa.Column('ai_feedback', postgresql.JSON(), nullable=True))
    
    # Update food table with new fields
    op.add_column('food_entries', sa.Column('meal_type', sa.String(), nullable=True))
    op.add_column('food_entries', sa.Column('fiber', sa.Float(), nullable=True))
    op.add_column('food_entries', sa.Column('sugar', sa.Float(), nullable=True))
    op.add_column('food_entries', sa.Column('glycemic_index', sa.Integer(), nullable=True))
    op.add_column('food_entries', sa.Column('glycemic_load', sa.Float(), nullable=True))
    op.add_column('food_entries', sa.Column('serving_size', sa.Float(), nullable=True))
    op.add_column('food_entries', sa.Column('serving_unit', sa.String(), nullable=True))
    op.add_column('food_entries', sa.Column('source', sa.String(), default='manual'))
    op.add_column('food_entries', sa.Column('meta_data', postgresql.JSON(), nullable=True))
    
    # Update recommendations table with feedback fields
    op.add_column('recommendations', sa.Column('is_helpful', sa.Boolean(), nullable=True))
    op.add_column('recommendations', sa.Column('user_rating', sa.Integer(), nullable=True))
    op.add_column('recommendations', sa.Column('user_feedback', sa.Text(), nullable=True))
    op.add_column('recommendations', sa.Column('is_implemented', sa.Boolean(), nullable=True))
    op.add_column('recommendations', sa.Column('implementation_result', sa.Text(), nullable=True))
    op.add_column('recommendations', sa.Column('suggested_time', sa.DateTime(), nullable=True))
    op.add_column('recommendations', sa.Column('action_taken', sa.Boolean(), nullable=True))
    op.add_column('recommendations', sa.Column('action_taken_time', sa.DateTime(), nullable=True))
    op.add_column('recommendations', sa.Column('suggested_action', sa.Text(), nullable=True))
    
    # Create activity_logs table
    op.create_table(
        'activity_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('activity_type', sa.String()),
        sa.Column('duration_minutes', sa.Integer()),
        sa.Column('intensity', sa.String()),
        sa.Column('calories_burned', sa.Float(), nullable=True),
        sa.Column('steps', sa.Integer(), nullable=True),
        sa.Column('heart_rate_avg', sa.Integer(), nullable=True),
        sa.Column('timestamp', sa.DateTime(), default=sa.func.now()),
        sa.Column('source', sa.String(), default='manual'),
        sa.Column('meta_data', postgresql.JSON(), nullable=True)
    )
    
    # Create mood_logs table
    op.create_table(
        'mood_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('rating', sa.Integer()),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('tags', sa.String(), nullable=True),
        sa.Column('timestamp', sa.DateTime(), default=sa.func.now())
    )
    
    # Create sleep_logs table
    op.create_table(
        'sleep_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('start_time', sa.DateTime()),
        sa.Column('end_time', sa.DateTime()),
        sa.Column('duration_minutes', sa.Integer()),
        sa.Column('quality', sa.Integer(), nullable=True),
        sa.Column('deep_sleep_minutes', sa.Integer(), nullable=True),
        sa.Column('light_sleep_minutes', sa.Integer(), nullable=True),
        sa.Column('rem_sleep_minutes', sa.Integer(), nullable=True),
        sa.Column('awake_minutes', sa.Integer(), nullable=True),
        sa.Column('heart_rate_avg', sa.Integer(), nullable=True),
        sa.Column('source', sa.String(), default='manual'),
        sa.Column('meta_data', postgresql.JSON(), nullable=True)
    )
    
    # Create medication_logs table
    op.create_table(
        'medication_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('name', sa.String()),
        sa.Column('dosage', sa.String()),
        sa.Column('units', sa.String(), nullable=True),
        sa.Column('timestamp', sa.DateTime(), default=sa.func.now()),
        sa.Column('taken', sa.Boolean(), default=True),
        sa.Column('notes', sa.String(), nullable=True)
    )
    
    # Create illness_logs table
    op.create_table(
        'illness_logs',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('name', sa.String()),
        sa.Column('severity', sa.Integer()),
        sa.Column('symptoms', sa.String(), nullable=True),
        sa.Column('start_date', sa.DateTime(), default=sa.func.now()),
        sa.Column('end_date', sa.DateTime(), nullable=True),
        sa.Column('notes', sa.String(), nullable=True)
    )
    
    # Create menstrual_cycles table
    op.create_table(
        'menstrual_cycles',
        sa.Column('id', sa.Integer(), primary_key=True, index=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('start_date', sa.DateTime()),
        sa.Column('end_date', sa.DateTime(), nullable=True),
        sa.Column('cycle_length', sa.Integer(), nullable=True),
        sa.Column('period_length', sa.Integer(), nullable=True),
        sa.Column('symptoms', sa.String(), nullable=True),
        sa.Column('flow_level', sa.Integer(), nullable=True),
        sa.Column('notes', sa.String(), nullable=True)
    )


def downgrade():
    # Drop new tables
    op.drop_table('menstrual_cycles')
    op.drop_table('illness_logs')
    op.drop_table('medication_logs')
    op.drop_table('sleep_logs')
    op.drop_table('mood_logs')
    op.drop_table('activity_logs')
    
    # Remove columns from recommendations table
    op.drop_column('recommendations', 'suggested_action')
    op.drop_column('recommendations', 'action_taken_time')
    op.drop_column('recommendations', 'action_taken')
    op.drop_column('recommendations', 'suggested_time')
    op.drop_column('recommendations', 'implementation_result')
    op.drop_column('recommendations', 'is_implemented')
    op.drop_column('recommendations', 'user_feedback')
    op.drop_column('recommendations', 'user_rating')
    op.drop_column('recommendations', 'is_helpful')
    
    # Remove columns from food_entries table
    op.drop_column('food_entries', 'meta_data')
    op.drop_column('food_entries', 'source')
    op.drop_column('food_entries', 'serving_unit')
    op.drop_column('food_entries', 'serving_size')
    op.drop_column('food_entries', 'glycemic_load')
    op.drop_column('food_entries', 'glycemic_index')
    op.drop_column('food_entries', 'sugar')
    op.drop_column('food_entries', 'fiber')
    op.drop_column('food_entries', 'meal_type')
    
    # Remove columns from users table
    op.drop_column('users', 'ai_feedback')
    op.drop_column('users', 'privacy_preferences')
    op.drop_column('users', 'notification_preferences')
    op.drop_column('users', 'diagnosis_date')
    op.drop_column('users', 'diabetes_type')
    op.drop_column('users', 'gender')
    op.drop_column('users', 'birthdate')
    op.drop_column('users', 'weight_kg')
    op.drop_column('users', 'height_cm')
    op.drop_column('users', 'third_party_tokens')
    op.drop_column('users', 'fitbit_authorized')
    op.drop_column('users', 'google_fit_authorized')
    op.drop_column('users', 'apple_health_authorized')
    op.drop_column('users', 'myfitnesspal_password')
    op.drop_column('users', 'myfitnesspal_username')
