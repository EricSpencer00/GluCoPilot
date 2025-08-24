#!/bin/bash

# GluCoPilot backend start script
# Usage: ./scripts/start_backend.sh

# Set a higher ulimit to avoid "too many open files" error
ulimit -n 8192

# Define root directory
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
export PYTHONPATH="$(cd "$(dirname "$0")/.." && pwd)"

# Get the user's local IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
  # MacOS
  IP_ADDRESS=$(ipconfig getifaddr en0)
  if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(ipconfig getifaddr en1)
  fi
else
  # Linux and others
  IP_ADDRESS=$(hostname -I | awk '{print $1}')
fi

if [ -z "$IP_ADDRESS" ]; then
  echo "Could not determine your local IP address. Using 127.0.0.1"
  IP_ADDRESS="127.0.0.1"
fi

echo "Your local IP address is: $IP_ADDRESS"

# Debug: Print PYTHONPATH and working directory
echo "[DEBUG] PYTHONPATH is: $PYTHONPATH"
echo "[DEBUG] Current working directory: $(pwd)"
echo "[DEBUG] backend/api/ contents:"
ls -l "$ROOT_DIR/backend/api/"
echo "[DEBUG] backend/services/ contents:"
ls -l "$ROOT_DIR/backend/services/"

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

# Start the backend server with auto-reload
echo "Starting GluCoPilot backend (with auto-reload)..."
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# Check if backend started successfully
sleep 3
if ! ps -p $BACKEND_PID > /dev/null; then
    echo "Failed to start backend server. Check logs for details."
    exit 1
else
    echo "Backend server started successfully (PID: $BACKEND_PID)"
fi

echo "GluCoPilot backend is running. Press Ctrl+C to stop."

# Function to handle termination
cleanup() {
    echo "Shutting down GluCoPilot backend..."
    kill $BACKEND_PID 2>/dev/null
    exit 0
}

# Set up trap for cleanup
trap cleanup INT TERM

# Wait for backend process to finish
wait $BACKEND_PID
