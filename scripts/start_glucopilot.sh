#!/bin/bash

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

# Update the app.json with the correct IP address
sed -i.bak "s|\"API_BASE_URL\": \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]\{1,5\}\"|\"API_BASE_URL\": \"http://$IP_ADDRESS:8000\"|g" "$ROOT_DIR/frontend/app.json"
rm -f "$ROOT_DIR/frontend/app.json.bak"

echo "Updated app.json with API_BASE_URL: http://$IP_ADDRESS:8000"

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
python -m uvicorn main:app --host 0.0.0.0 --port 8000 &
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
npx expo start --clear &
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
