import SwiftUI
import AuthenticationServices
import HealthKit

@main
struct GluCoPilotApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var apiManager = APIManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthManager)
                .environmentObject(apiManager)
                .withGlobalTopGradient()
                // HealthKit permission requests are handled by the auth/HealthKit setup flow
                // (for example, `HealthKitSetupView`) and should not be triggered unconditionally
                // on app launch. Requesting too early can cause sandbox/service entitlement errors
                // or unexpected system logs when running in simulator/device environments.
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    let refreshed = await authManager.refreshAppleIDTokenIfNeeded()
                    if refreshed {
                        print("[App] Apple id_token refreshed on becoming active")
                    }
                    // Ensure HealthKit observation is running and proactively refresh recent glucose samples
                    healthManager.startObservingAndRefresh()
                }
            }
        }
    }
}
