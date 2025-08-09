"""
Add new columns to recommendations table

Revision ID: 20250808_add_columns_to_recommendations
Revises: d548a4f6e576
Create Date: 2025-08-08 17:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20250808_add_columns_to_recommendations'
down_revision: Union[str, None] = 'd548a4f6e576'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column('recommendations', sa.Column('title', sa.String(length=128), nullable=True))
    op.add_column('recommendations', sa.Column('category', sa.String(length=64), nullable=True))
    op.add_column('recommendations', sa.Column('priority', sa.String(length=32), nullable=True))
    op.add_column('recommendations', sa.Column('confidence_score', sa.Float, nullable=True))
    op.add_column('recommendations', sa.Column('context_data', sa.Text, nullable=True))

def downgrade() -> None:
    op.drop_column('recommendations', 'title')
    op.drop_column('recommendations', 'category')
    op.drop_column('recommendations', 'priority')
    op.drop_column('recommendations', 'confidence_score')
    op.drop_column('recommendations', 'context_data')
