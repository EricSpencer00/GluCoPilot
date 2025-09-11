# GluCoPilot iOS App

A modern SwiftUI-based iOS application for AI-powered diabetes management, built with iOS 18+ components and Swift 6.

## Overview

GluCoPilot helps users manage their diabetes by integrating health data and providing AI-powered insights and recommendations. The app uses Apple HealthKit and MyFitnessPal to create a comprehensive diabetes management platform.

## Features

### 🔐 Authentication
- Apple Sign In integration
- Secure keychain storage for credentials
- Automatic authentication state management

### 📊 Data Integration
- **Apple HealthKit**: Glucose, steps, heart rate, sleep, exercise data
- **MyFitnessPal**: Nutrition and food logging (via Apple Health)
- Automatic data synchronization with backend

### 🧠 AI Insights
- Personalized glucose management recommendations
- Pattern recognition and trend analysis
- Predictive insights for glucose levels
- Correlation analysis between lifestyle factors and glucose

### 📱 Modern UI/UX
- Built with SwiftUI and iOS 18+ components
- Dark mode support
- Responsive design for iPhone and iPad
- Intuitive tab-based navigation
- Real-time data updates

## Architecture

### MVVM Pattern
The app follows the Model-View-ViewModel pattern with:
- **Views**: SwiftUI views for UI presentation
- **Managers**: Business logic and data management
- **Models**: Data structures and API responses

### Key Components

#### Managers
- `AuthenticationManager`: Handles Apple Sign In and authentication state
- `HealthKitManager`: Manages Apple HealthKit integration
- `DexcomManager`: Handles Dexcom CGM data and authentication
- `APIManager`: Backend API communication and data synchronization

# GluCoPilot iOS App

A modern SwiftUI-based iOS application for AI-powered diabetes management, built with iOS 18+ components and Swift 6.

## Overview

GluCoPilot helps users manage their diabetes by integrating health data and providing AI-powered insights and recommendations. The app uses Apple HealthKit and MyFitnessPal to create a comprehensive diabetes management platform.

## Features

### 🔐 Authentication
- Apple Sign In integration
- Secure keychain storage for credentials
- Automatic authentication state management

### 📊 Data Integration
- **Apple HealthKit**: Glucose, steps, heart rate, sleep, exercise data
- **MyFitnessPal**: Nutrition and food logging (via Apple Health)
- Automatic data synchronization with backend

### 🧠 AI Insights
- Personalized glucose management recommendations
- Pattern recognition and trend analysis
- Predictive insights for glucose levels
- Correlation analysis between lifestyle factors and glucose

### 📱 Modern UI/UX
- Built with SwiftUI and iOS 18+ components
- Dark mode support
- Responsive design for iPhone and iPad
- Intuitive tab-based navigation
- Real-time data updates

## Architecture

### MVVM Pattern
The app follows the Model-View-ViewModel pattern with:
- **Views**: SwiftUI views for UI presentation
- **Managers**: Business logic and data management
- **Models**: Data structures and API responses

### Key Components

#### Managers
- `AuthenticationManager`: Handles Apple Sign In and authentication state
- `HealthKitManager`: Manages Apple HealthKit integration
- `APIManager`: Backend API communication and data synchronization

#### Views
- `ContentView`: Root view with authentication flow
- `MainTabView`: Main tab navigation with dashboard
- `DashboardView`: Overview of glucose, health metrics, and quick actions
- `DataSyncView`: Health data synchronization interface
- `AIInsightsView`: AI-powered insights and recommendations
- `SettingsView`: App settings and account management

#### Utilities
- `KeychainHelper`: Secure storage for sensitive data

## Technical Requirements

- macOS with Xcode 16+ and iOS 18+ SDK
- Swift 6.0
- An Apple Developer account for provisioning (required for Apple Sign In and HealthKit on device)

## Permissions Required

- **Apple Sign In**: User authentication
- **HealthKit**: Health data reading (glucose, steps, heart rate, sleep, nutrition)
- **Network**: API communication for data sync and AI insights

## Setup Instructions

1. Open the Xcode project/workspace:

```bash
open GluCoPilot.xcodeproj
```

2. Team, bundle ID, and capabilities:
- In Xcode, select the app target -> Signing & Capabilities.
- Set your development team and update the bundle identifier to a unique value.
- Add the Apple Sign In and HealthKit capabilities and confirm the entitlements file is configured.

3. Configure the API base URL:
- Update the backend URL used by the app in `GluCoPilot/Managers/APIManager.swift` (or `Constants.swift` if present). Use `http://localhost:8000` for local development, or your deployed backend URL for remote testing.

4. Run on simulator or device:
- Simulator: HealthKit is limited on simulator — for full HealthKit testing use a device and sandbox/test accounts where possible.
- Device: Ensure provisioning is set up and capabilities are enabled.

5. Backend notes:
- Start the backend (see project root README) before launching the app to allow API communication and AI insights.
- If you enable Apple Sign In or Dexcom integration, you may need to configure credentials in `backend/.env` (see `backend/.env.example`).

## Key Files

```
GluCoPilot/
├── GluCoPilotApp.swift          # App entry point
├── ContentView.swift            # Root view with auth flow
├── Info.plist                   # App configuration
├── GluCoPilot.entitlements      # App capabilities
├── Assets.xcassets/             # App icons and colors
├── Views/
│   ├── LaunchScreen.swift       # Animated launch screen
│   ├── MainTabView.swift        # Tab navigation and dashboard
│   ├── AppleSignInView.swift    # Authentication interface
│   ├── DataSyncView.swift       # Health data sync
│   ├── AIInsightsView.swift     # AI recommendations
│   └── SettingsView.swift       # App settings
├── Managers/
│   ├── AuthenticationManager.swift  # Auth handling
│   ├── HealthKitManager.swift       # HealthKit integration
│   └── APIManager.swift             # Backend communication
└── Utilities/
    └── KeychainHelper.swift         # Secure storage
```

## Data Flow

1. **Authentication**: User signs in with Apple ID
2. **Data Connection**: Enable HealthKit and grant the app permission to read health data
3. **Data Sync**: Automatic synchronization of glucose and health data
4. **AI Processing**: Backend analyzes data patterns
5. **Insights Delivery**: Personalized recommendations delivered to app

## API Integration

The app communicates with the GluCoPilot backend API for:
- User authentication and management
- Glucose and health data storage and retrieval (via HealthKit)
- Health data synchronization
- AI insight generation
- Data analytics and pattern recognition

## Security

- All sensitive data stored in iOS Keychain
- Network requests use HTTPS
- Apple Sign In provides secure authentication
- HealthKit data access controlled by user permissions

## Development Status

This is a modern rewrite of the original React Native app, built specifically for iOS with:
- Native performance and reliability
- Better integration with iOS health ecosystem
- Modern SwiftUI architecture
- Enhanced user experience

## Future Enhancements

- Apple Watch companion app
- Shortcuts and Siri integration
- Advanced data visualization
- Predictive notifications
- Integration with additional health devices

## Contributing

This app is part of the GluCoPilot ecosystem. For backend integration and API documentation, refer to the main project repository.
