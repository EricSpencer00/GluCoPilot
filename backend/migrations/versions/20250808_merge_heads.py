"""
Merge heads d548a4f6e576 and 20250808_add_columns_to_recommendations

Revision ID: 20250808_merge_heads
Revises: d548a4f6e576, 20250808_add_columns_to_recommendations
Create Date: 2025-08-08 17:10:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20250808_merge_heads'
down_revision: Union[str, tuple] = ('d548a4f6e576', '20250808_add_columns_to_recommendations')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    pass  # This migration just merges two heads; no schema changes

def downgrade() -> None:
    pass  # This migration just merges two heads; no schema changes
