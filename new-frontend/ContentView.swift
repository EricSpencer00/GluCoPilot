import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AppleSignInView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager())
        .environmentObject(DexcomManager())
        .environmentObject(APIManager())
}
