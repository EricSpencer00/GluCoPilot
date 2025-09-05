import SwiftUI

/// Central state management for app-level UI state and flags
class AppState: ObservableObject {
    // MARK: - Launching and Onboarding
    @Published var isLaunching: Bool = true
    
    @AppStorage("hasSeenOnboarding") 
    var hasSeenOnboarding: Bool = false
    
    @AppStorage("hasCompletedHealthKitSetup") 
    var hasCompletedHealthKitSetup: Bool = false
    
    // MARK: - Health and Authentication flags
    @Published var requiresHealthKitAuthorization: Bool = false
    
    // MARK: - Debug settings
    @AppStorage("showHealthKitPermissionLogs") 
    var showHealthKitPermissionLogs: Bool = false
    
    @AppStorage("showDebugUI") 
    var showDebugUI: Bool = false
    
    // MARK: - Methods
    func completeOnboarding() {
        hasSeenOnboarding = true
    }
    
    func completeHealthKitSetup() {
        hasCompletedHealthKitSetup = true
        requiresHealthKitAuthorization = false
    }
    
    func startLaunchSequence() async {
        // Keep the launch screen visible at least briefly for polish
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        await MainActor.run {
            isLaunching = false
        }
    }
}
