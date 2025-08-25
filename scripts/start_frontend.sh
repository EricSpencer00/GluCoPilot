#!/bin/bash


echo "[INFO] USB-only mode: Make sure your device is connected via USB."
echo "[INFO] Set API_BASE_URL in your .env to http://127.0.0.1:8000 for backend access."


# Change to the frontend directory
cd "$(dirname "$0")/frontend"


# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi


# Start the Expo development server with clear cache
echo "Starting GluCoPilot frontend..."
npx expo start --clear
