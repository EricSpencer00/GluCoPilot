#!/bin/bash

# Create a simple iOS project using SwiftUI
cd /Users/ericspencer/GitHub/GluCoPilot/new-frontend

# Create a basic Package.swift for SPM project
cat > Package.swift << 'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GluCoPilot",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "GluCoPilot",
            targets: ["GluCoPilot"]
        ),
    ],
    targets: [
        .target(
            name: "GluCoPilot",
            path: "GluCoPilot"
        ),
    ]
)
EOF

echo "Package.swift created. You can now:"
echo "1. Open Terminal and run: cd /Users/ericspencer/GitHub/GluCoPilot/new-frontend"
echo "2. Run: swift package generate-xcodeproj"
echo "3. Or use Xcode: File > Open and select the new-frontend folder"
echo "4. Or use 'open Package.swift' to open as Swift Package in Xcode"
