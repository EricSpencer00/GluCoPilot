"""
Add refresh_token to User model

Revision ID: add_refresh_token_to_user
Revises: 5dc2b235f622
Create Date: 2025-08-09 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_refresh_token_to_user'
down_revision = '5dc2b235f622'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('users', sa.Column('refresh_token', sa.String(), nullable=True))

def downgrade():
    op.drop_column('users', 'refresh_token')