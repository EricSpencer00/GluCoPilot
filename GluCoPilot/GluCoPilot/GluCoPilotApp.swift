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
                .onAppear {
                    // For now, request HealthKit permissions immediately on first UI appearance.
                    // This is a temporary measure to ensure the permission prompt is shown reliably
                    // before we start observation. We may move this into an onboarding flow later.
                    healthManager.requestHealthKitPermissions()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    let refreshed = await authManager.refreshAppleIDTokenIfNeeded()
                    if refreshed {
                        print("[App] Apple id_token refreshed on becoming active")
                    }
                    // Ensure HealthKit permissions are requested (if not determined) and start observation/refresh.
                    // Requesting permissions before starting observations avoids the "permissions not granted" race.
                    if healthManager.authorizationStatus == .notDetermined {
                        healthManager.requestHealthKitPermissions()
                    }

                    // Start observing and proactively refresh recent glucose samples. If permissions are
                    // not yet granted this call will be a no-op; when/if the user grants permissions the
                    // `requestHealthKitPermissions` completion path will call `startGlucoseObserving()`.
                    healthManager.startObservingAndRefresh()
                }
            }
        }
    }
}
