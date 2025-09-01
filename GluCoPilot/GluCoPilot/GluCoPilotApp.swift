import SwiftUI
import AuthenticationServices
import HealthKit

@main
struct GluCoPilotApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var dexcomManager = DexcomManager()
    @StateObject private var apiManager = APIManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthManager)
                .environmentObject(dexcomManager)
                .environmentObject(apiManager)
                .onAppear {
                    healthManager.requestHealthKitPermissions()
                }
        }
    }
}
