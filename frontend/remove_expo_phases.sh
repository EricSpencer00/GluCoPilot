#!/bin/bash

# Script to remove Expo build phases from Xcode project
cd /Users/ericspencer/GitHub/GluCoPilot/frontend/ios

echo "Removing Expo build phases from Xcode project..."

# Remove the Expo Configure project build phase
sed -i '' '/307E960B506F6BF08A8F102D.*\[Expo\].*Configure project/d' GluCoPilotDev.xcodeproj/project.pbxproj

# Remove the build phase definition
sed -i '' '/307E960B506F6BF08A8F102D.*=.*{/,/};/d' GluCoPilotDev.xcodeproj/project.pbxproj

echo "Expo build phases removed successfully!"
