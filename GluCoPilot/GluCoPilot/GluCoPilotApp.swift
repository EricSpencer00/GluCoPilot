import SwiftUI
import AuthenticationServices
import HealthKit

@main
struct GluCoPilotApp: App {
    // Centralized state management
    @StateObject private var appState = AppState()
    
    // Single source of truth for all managers
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var apiManager = APIManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(healthManager)
                .environmentObject(apiManager)
                .withGlobalTopGradient()
                .onAppear {
                    // Inject the apiManager dependency
                    authManager.apiManager = apiManager
                    // Inject HealthKitManager dependency
                    authManager.healthKitManager = healthManager
                    
                    // Start launch sequence
                    Task {
                        // Kick off auth check which may trigger async token refresh
                        authManager.checkAuthenticationStatus()
                        await appState.startLaunchSequence()
                    }
                }
                // HealthKit permission requests are handled by the auth/HealthKit setup flow
                // (for example, `HealthKitSetupView`) and should not be triggered unconditionally
                // on app launch. Requesting too early can cause sandbox/service entitlement errors
                // or unexpected system logs when running in simulator/device environments.
        }
    }
}
