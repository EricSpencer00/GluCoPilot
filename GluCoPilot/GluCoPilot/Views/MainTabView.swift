import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var apiManager: APIManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Dashboard Tab
            DashboardView(selectedTab: $selectedTab)
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Log tab — log food, insulin, and other events
            LogView()
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "drop.fill" : "drop")
                    Text("Glucose")
                }
                .tag(1)
            
            // Insights Tab (previously Data)
            AIInsightsView()
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "brain.head.profile.fill" : "brain.head.profile")
                    Text("AI")
                }
                .tag(2)
            
            // Graph Tab
            GraphingView()
                .environmentObject(apiManager)
                .tabItem {
                    // Use a widely available chart symbol to avoid missing symbol on older OSes
                    Image(systemName: selectedTab == 3 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                    Text("Graphs")
                }
                .tag(3)
            
            // AI Insights Tab
            // Removed duplicate Insights tab (consolidated under tag 2)
            
            // Settings Tab
            SettingsView()
                .environmentObject(healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 5 ? "gearshape.fill" : "gearshape")
                    Text("Settings")
                }
                .tag(5)

#if DEBUG
            // Debug Tab (only in debug builds)
            APIRequestDebugView(healthKitManager: healthKitManager)
                .environmentObject(apiManager)
                .tabItem {
                    Image(systemName: selectedTab == 99 ? "ant.fill" : "ant")
                    Text("Debug")
                }
                .tag(99)
#endif
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
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var apiManager: APIManager
    @Binding var selectedTab: Int
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
                    QuickActionsView(selectedTab: $selectedTab)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await refreshDashboard()
            }
        }
    .withTopGradient()
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func refreshDashboard() async {
        // Refresh all data
        // Do not request permissions automatically during a refresh. Permission requests
        // should be initiated by explicit user action (HealthKitSetupView / Settings).
        // Instead, update published properties if permissions already granted.
        if healthKitManager.authorizationStatus == .sharingAuthorized {
            await healthKitManager.updatePublishedProperties()
        }
        // Trigger a backend sync or fetch latest aggregated glucose via APIManager
//        try? await apiManager.fetchLatestSyncedGlucoseIfNeeded()
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
                Image(compatibleSystemName: icon, fallback: "questionmark.circle")
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
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var latestGlucoseValue: Int? = nil
    @State private var latestGlucoseTimestamp: Date? = nil

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

            if let value = latestGlucoseValue {
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
                        Image(systemName: "waveform.path.ecg")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("From HealthKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No recent glucose data")
                        .foregroundColor(.secondary)
                        .italic()
                    Button(action: {
                        Task {
                            healthKitManager.requestHealthKitPermissions()
                            do {
                                let data = try await healthKitManager.fetchLast24HoursData()
                                if let last = data.glucose.last {
                                    await MainActor.run {
                                        self.latestGlucoseValue = Int(last.value)
                                        self.latestGlucoseTimestamp = last.timestamp
                                    }
                                }
                            } catch {
                                // keep nil and let the UI show the message
                            }
                        }
                    }) {
                        Text("Sync Health Data")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .task {
            await fetchLatestGlucose()
        }
    }

    private func fetchLatestGlucose() async {
        // Only attempt to fetch if HealthKit permissions were granted
        guard healthKitManager.authorizationStatus == .sharingAuthorized else { return }
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            if let last = data.glucose.last {
                await MainActor.run {
                    self.latestGlucoseValue = Int(last.value)
                    self.latestGlucoseTimestamp = last.timestamp
                }
            }
        } catch {
            // No-op: keep nil to show placeholder
        }
    }

    private func getTimestamp() -> String {
        guard let timestamp = latestGlucoseTimestamp else { return "" }
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
            
            // Show an empty state that directs users to sync data or open the Logs tab
            VStack(spacing: 8) {
                Text("No recent activity to show")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button(action: {
                        // Navigate to Log tab — caller binds Index 1
                        // This button will be handled by QuickActionsView in practice
                    }) {
                        Text("Open Log")
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                    }

                    Button(action: {
                        // Trigger a sync via HealthKit permissions
                        let manager = HealthKitManager()
                        manager.requestHealthKitPermissions()
                    }) {
                        Text("Sync HealthKit")
                            .font(.caption)
                    }
                    .buttonStyle(GradientButtonStyle(colors: [Color.green, Color.blue]))
                    }
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
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var apiManager: APIManager
    @Binding var selectedTab: Int

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
                    Task {
                        do {
                            let healthData = try await healthKitManager.fetchLast24HoursData()
                            let nutritionSource = healthData.nutrition.first
                                    let apiHealthData = APIManagerHealthData(
                                        glucose: healthData.glucose.map { sample in
                                            APIManagerGlucoseReading(
                                                value: Int(sample.value),
                                                trend: "",
                                                timestamp: sample.timestamp,
                                                unit: sample.unit
                                            )
                                        },
                                workouts: healthData.workouts.map { workout in
                                    APIManagerWorkoutData(
                                        type: workout.name,
                                        duration: workout.duration,
                                        calories: workout.calories,
                                        startDate: workout.startDate,
                                        endDate: workout.endDate
                                    )
                                },
                                nutrition: [APIManagerNutritionData(
                                    name: nutritionSource?.name ?? "Daily Nutrition",
                                    calories: nutritionSource?.calories ?? 0,
                                    carbs: nutritionSource?.carbs ?? 0,
                                    protein: nutritionSource?.protein ?? 0,
                                    fat: nutritionSource?.fat ?? 0,
                                    timestamp: nutritionSource?.timestamp ?? Date()
                                )],
                                timestamp: Date()
                            )

                            _ = try await apiManager.syncHealthData(apiHealthData)
                        } catch {
                            print("Sync failed: \(error)")
                        }
                    }
                }
                
                QuickActionButton(
                    title: "Log Meal",
                    icon: "fork.knife.circle.fill",
                    color: .orange
                ) {
                    selectedTab = 1
                }
                
                QuickActionButton(
                    title: "View Log",
                    icon: "list.bullet.rectangle",
                    color: .green
                ) {
                    selectedTab = 1
                }
                
                QuickActionButton(
                    title: "Get Insights",
                    icon: "brain.head.profile.fill",
                    color: .purple
                ) {
                    selectedTab = 2
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
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle(colors: [color, color.opacity(0.8)]))
    }
}

#Preview {
    MainTabView()
}
