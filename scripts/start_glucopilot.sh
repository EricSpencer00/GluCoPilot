#!/bin/bash

# Set a higher ulimit to avoid "too many open files" error
ulimit -n 8192q

# Check for python and required packages
echo "Checking for required Python packages..."
cd backend

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install required packages
pip install -r requirements.txt

# Start the backend server
echo "Starting GluCoPilot backend..."
uvicorn main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!

# Move to frontend and install/update packages
echo "Setting up frontend..."
cd ../frontend

# Fix any dependency issues
echo "Fixing dependencies..."
npm install
npx expo install --fix

# Start the frontend
echo "Starting GluCoPilot frontend..."
npm start &
FRONTEND_PID=$!

# Function to handle termination
cleanup() {
    echo "Shutting down GluCoPilot..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
    exit 0
}

# Set up trap for cleanup
trap cleanup INT TERM

# Wait for all background processes to finish
echo "GluCoPilot is running. Press Ctrl+C to stop."
wait
