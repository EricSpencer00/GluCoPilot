import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dexcomManager: DexcomManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                if dexcomManager.isConnected {
                    AIInsightsView()
                } else {
                    DexcomConnectionView()
                }
            }
            .tabItem {
                Label("Insights", systemImage: "brain.head.profile")
            }
            .tag(0)
            
            NavigationStack {
                DataSyncView()
            }
            .tabItem {
                Label("Data", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(1)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager())
        .environmentObject(DexcomManager())
        .environmentObject(APIManager())
}
