import SwiftUI
import AuthenticationServices
import HealthKit

@main
struct GluCoPilotApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var apiManager = APIManager()
    
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
    }
}
