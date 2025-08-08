#!/bin/bash

# Set a higher ulimit to avoid "too many open files" error
ulimit -n 8192

# Define root directory
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Check for python and required packages
echo "Checking for required Python packages..."
cd "$ROOT_DIR/backend" || { echo "Failed to change to backend directory"; exit 1; }

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
cd "$ROOT_DIR/backend" || { echo "Failed to change to backend directory"; exit 1; }
python -m uvicorn main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!

# Check if backend started successfully
sleep 3
if ! ps -p $BACKEND_PID > /dev/null; then
    echo "Failed to start backend server. Check logs for details."
    exit 1
else
    echo "Backend server started successfully (PID: $BACKEND_PID)"
fi

# Move to frontend and install/update packages
echo "Setting up frontend..."
cd "$ROOT_DIR/frontend" || { echo "Failed to change to frontend directory"; exit 1; }

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
