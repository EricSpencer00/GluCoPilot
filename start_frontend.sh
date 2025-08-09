#!/bin/bash

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
sed -i.bak "s|\"API_BASE_URL\": \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]\{1,5\}\"|\"API_BASE_URL\": \"http://$IP_ADDRESS:8000\"|g" "$(dirname "$0")/frontend/app.json"
rm -f "$(dirname "$0")/frontend/app.json.bak"

echo "Updated app.json with API_BASE_URL: http://$IP_ADDRESS:8000"

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
