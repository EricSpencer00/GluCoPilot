#!/bin/bash

# Change to the frontend directory
cd "$(dirname "$0")/frontend"

echo "🧹 Cleaning up existing installation..."
rm -rf node_modules
rm -rf .expo
rm -f package-lock.json
rm -f yarn.lock
rm -f pnpm-lock.yaml

echo "🧼 Clearing npm cache..."
npm cache clean --force

echo "📦 Installing dependencies..."
npm install --legacy-peer-deps

echo "🔧 Fixing Expo dependencies..."
npx expo install --fix

echo "✅ Dependencies installation complete!"
echo "🚀 To start the app, run: ./start_frontend.sh"
