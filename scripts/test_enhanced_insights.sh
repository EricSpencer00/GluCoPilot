#!/bin/bash

# Script to test the new AI insights implementation
# Usage: ./test_enhanced_insights.sh [user_id]

set -e

USER_ID=${1:-1}  # Default to user ID 1 if not provided
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Activate virtual environment if it exists
if [ -d "$PROJECT_ROOT/backend/venv" ]; then
    echo "Activating virtual environment..."
    source "$PROJECT_ROOT/backend/venv/bin/activate"
else
    echo "Virtual environment not found. Please set up the backend first."
    echo "Run: cd backend && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# Check if required packages are installed
echo "Checking dependencies..."
pip install -q pytest pytest-cov requests

# Run database migrations
echo "Running database migrations..."
cd "$PROJECT_ROOT/backend"
python -m alembic upgrade head

# Generate sample data for testing
echo "Generating sample data for all data streams..."
cd "$PROJECT_ROOT/backend/scripts"
python generate_sample_data.py --user_id $USER_ID --include_all_streams

# Run AI insights tests
echo "Testing AI insights engine..."
cd "$PROJECT_ROOT"
python -m pytest ai/test_insights_engine.py -v

# Run the insights engine with the new data
echo "Generating insights for user $USER_ID..."
cd "$PROJECT_ROOT/ai"
python insights_engine.py --user_id $USER_ID --verbose

echo "Done! New AI insights have been generated and stored in the database."
echo "Check the recommendations table for user $USER_ID to see the results."
