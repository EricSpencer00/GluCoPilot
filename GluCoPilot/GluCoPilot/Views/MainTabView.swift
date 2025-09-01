import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {
    @StateObject private var dexcomManager = DexcomManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var apiManager = APIManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Dashboard Tab
            DashboardView()
                .environmentObject(dexcomManager)
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Glucose/Dexcom Tab
            DexcomConnectionView()
                .environmentObject(dexcomManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "drop.fill" : "drop")
                    Text("Glucose")
                }
                .tag(1)
            
            // Data Tab
            DataSyncView()
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                    Text("Data")
                }
                .tag(2)
            
            // Graph Tab
            GraphingView()
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "chart.xyaxis.line.fill" : "chart.xyaxis.line")
                    Text("Graphs")
                }
                .tag(3)
            
            // AI Insights Tab
            AIInsightsView()
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "brain.head.profile.fill" : "brain.head.profile")
                    Text("Insights")
                }
                .tag(4)
            
            // Settings Tab
            SettingsView()
                .environmentObject(dexcomManager)
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 5 ? "gearshape.fill" : "gearshape")
                    Text("Settings")
                }
                .tag(5)
    }
    .environmentObject(apiManager)
    .accentColor(.accentColor)
    .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct DashboardView: View {
    @EnvironmentObject private var dexcomManager: DexcomManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var apiManager: APIManager
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome Header
                    WelcomeHeaderView()
                    
                    // Quick Stats Cards
                    QuickStatsView()
                    
                    // Latest Glucose Reading
                    LatestGlucoseView()
                    
                    // Recent Activity
                    RecentActivityView()
                    
                    // Quick Actions
                    QuickActionsView()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await refreshDashboard()
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func refreshDashboard() async {
        // Refresh all data
        try? await dexcomManager.fetchLatestGlucoseReading(apiManager: apiManager)
        healthKitManager.requestHealthKitPermissions()
    }
}

struct WelcomeHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Good \(getGreeting())")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Here's your diabetes overview")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.title)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
}

struct QuickStatsView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Steps Today",
                value: "\(healthKitManager.todaySteps)",
                icon: "figure.walk",
                color: .green
            )
            
            StatCard(
                title: "Active Minutes",
                value: "\(Int(healthKitManager.activeMinutes))",
                icon: "heart.fill",
                color: .red
            )
            
            StatCard(
                title: "Sleep Hours",
                value: String(format: "%.1f", healthKitManager.sleepHours),
                icon: "bed.double.fill",
                color: .purple
            )
            
            StatCard(
                title: "Heart Rate",
                value: "\(Int(healthKitManager.averageHeartRate))",
                icon: "heart.pulse",
                color: .pink
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct LatestGlucoseView: View {
    @EnvironmentObject private var dexcomManager: DexcomManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Glucose")
                    .font(.headline)
                Spacer()
                Text(getTimestamp())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let reading = dexcomManager.latestGlucoseReading {
                let value = reading.value
                let trend = reading.trend

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(value)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(getGlucoseColor(value))
                        Text("mg/dL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack {
                        Image(systemName: getTrendIcon(trend))
                            .font(.title)
                            .foregroundColor(getTrendColor(trend))
                        Text(trend)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No recent glucose data")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func getTimestamp() -> String {
    guard let reading = dexcomManager.latestGlucoseReading else { return "" }
    let timestamp = reading.timestamp
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    private func getGlucoseColor(_ value: Int) -> Color {
        switch value {
        case 70...180: return .green
        case 181...250: return .orange
        default: return .red
        }
    }
    
    private func getTrendIcon(_ trend: String) -> String {
        let normalized = trend.replacingOccurrences(of: "_", with: " ").lowercased()
        switch normalized {
        case "rising quickly", "rising_quickly": return "arrow.up.circle.fill"
        case "rising": return "arrow.up.right.circle.fill"
        case "stable", "flat": return "arrow.right.circle.fill"
        case "falling": return "arrow.down.right.circle.fill"
        case "falling quickly", "falling_quickly": return "arrow.down.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func getTrendColor(_ trend: String) -> Color {
        let normalized = trend.replacingOccurrences(of: "_", with: " ").lowercased()
        switch normalized {
        case "rising quickly", "falling quickly", "rising_quickly", "falling_quickly": return .red
        case "rising", "falling": return .orange
        case "stable", "flat": return .green
        default: return .gray
        }
    }
}

struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            VStack(spacing: 8) {
                ActivityRow(
                    icon: "drop.circle.fill",
                    title: "Glucose Reading",
                    subtitle: "145 mg/dL - Stable",
                    time: "5 min ago",
                    color: .green
                )
                
                ActivityRow(
                    icon: "figure.walk.circle.fill",
                    title: "Walk Completed",
                    subtitle: "2,847 steps - 23 min",
                    time: "2 hours ago",
                    color: .blue
                )
                
                ActivityRow(
                    icon: "fork.knife.circle.fill",
                    title: "Meal Logged",
                    subtitle: "Lunch - 45g carbs",
                    time: "4 hours ago",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Sync Data",
                    icon: "arrow.clockwise.circle.fill",
                    color: .blue
                ) {
                    // Handle sync action
                }
                
                QuickActionButton(
                    title: "Log Meal",
                    icon: "fork.knife.circle.fill",
                    color: .orange
                ) {
                    // Handle log meal action
                }
                
                QuickActionButton(
                    title: "View Trends",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: .green
                ) {
                    // Handle view trends action
                }
                
                QuickActionButton(
                    title: "Get Insights",
                    icon: "brain.head.profile.fill",
                    color: .purple
                ) {
                    // Handle get insights action
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainTabView()
}
