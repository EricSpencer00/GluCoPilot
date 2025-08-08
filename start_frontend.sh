#!/bin/bash

# Change to the frontend directory
cd "$(dirname "$0")/frontend"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Start the Expo development server
echo "Starting GluCoPilot frontend..."
npm start
