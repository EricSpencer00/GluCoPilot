"""add prediction tables

Revision ID: e784a3f6e125
Revises: d548a4f6e576
Create Date: 2025-08-08 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e784a3f6e125'
down_revision = 'd548a4f6e576'  # Update this to your last migration
branch_labels = None
depends_on = None


def upgrade():
    # Create prediction_models table
    op.create_table(
        'prediction_models',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('model_type', sa.String(), nullable=True),
        sa.Column('accuracy', sa.Float(), nullable=True),
        sa.Column('parameters', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_prediction_models_id'), 'prediction_models', ['id'], unique=False)

    # Create glucose_predictions table
    op.create_table(
        'glucose_predictions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('model_id', sa.Integer(), nullable=True),
        sa.Column('prediction_time', sa.DateTime(), nullable=True),
        sa.Column('target_time', sa.DateTime(), nullable=True),
        sa.Column('predicted_value', sa.Float(), nullable=True),
        sa.Column('confidence_interval_lower', sa.Float(), nullable=True),
        sa.Column('confidence_interval_upper', sa.Float(), nullable=True),
        sa.Column('is_high_risk', sa.Boolean(), nullable=True),
        sa.Column('is_low_risk', sa.Boolean(), nullable=True),
        sa.Column('actual_value', sa.Float(), nullable=True),
        sa.Column('inputs', sa.Text(), nullable=True),
        sa.Column('explanation', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['model_id'], ['prediction_models.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_glucose_predictions_id'), 'glucose_predictions', ['id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_glucose_predictions_id'), table_name='glucose_predictions')
    op.drop_table('glucose_predictions')
    op.drop_index(op.f('ix_prediction_models_id'), table_name='prediction_models')
    op.drop_table('prediction_models')
