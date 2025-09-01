#!/bin/bash

# Script to build and run iOS app from command line
# Usage: ./run_ios.sh

cd "$(dirname "$0")"

echo "🚀 Building and running GluCoPilot iOS app..."

# Clean and build
echo "📱 Cleaning iOS build..."
cd ios
rm -rf build
cd ..

# Run the app
echo "▶️ Running iOS app..."
npx react-native run-ios --scheme GluCoPilotDev --configuration Debug

echo "✅ iOS app should be starting now!"
