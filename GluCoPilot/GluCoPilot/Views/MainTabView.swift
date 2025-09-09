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

            // Insights Tab
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
                    Image(systemName: selectedTab == 3 ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                    Text("Graphs")
                }
                .tag(3)

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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                WelcomeBannerView()

                VStack(spacing: 12) {
                    LatestGlucoseView()
                        .frame(maxWidth: .infinity)

                    HealthKitStatsView()
                        .frame(maxWidth: .infinity)
                }

                QuickActionsView(selectedTab: $selectedTab)

                HealthKitActivitiesView()

                NutritionSummaryView()

                RecentActivityView()
            }
            .padding()
        }
        .withTopGradient()

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

struct WelcomeBannerView: View {
    @State private var currentTime = Date()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good \(getGreeting())")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(formattedDate())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: timeBasedIcon())
                    .font(.system(size: 36))
                    .foregroundStyle(timeBasedColor())
            }
            
            Text("Here's your diabetes overview for today")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    .cardStyle(baseColor: Color.blue, cornerRadius: 16)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 0..<5: return "Night"
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<22: return "Evening"
        default: return "Night"
        }
    }
    
    private func timeBasedIcon() -> String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 6..<8: return "sunrise.fill"
        case 8..<17: return "sun.max.fill"
        case 17..<20: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }
    
    private func timeBasedColor() -> Color {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 6..<8: return .orange
        case 8..<17: return .yellow
        case 17..<20: return .orange
        default: return .indigo
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: currentTime)
    }
}

struct HealthKitStatsView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Stats Today")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HealthStatCard(
                    title: "Steps",
                    value: "\(healthKitManager.todaySteps)",
                    icon: "figure.walk",
                    color: .green,
                    goal: 10000,
                    current: Double(healthKitManager.todaySteps)
                )
                
                HealthStatCard(
                    title: "Active Minutes",
                    value: "\(Int(healthKitManager.activeMinutes))",
                    icon: "flame.fill",
                    color: .orange,
                    goal: 30,
                    current: healthKitManager.activeMinutes
                )
                
                HealthStatCard(
                    title: "Sleep",
                    value: String(format: "%.1f hrs", healthKitManager.sleepHours),
                    icon: "bed.double.fill",
                    color: .indigo,
                    goal: 8,
                    current: healthKitManager.sleepHours
                )
                
                HealthStatCard(
                    title: "Heart Rate",
                    value: "\(Int(healthKitManager.averageHeartRate)) bpm",
                    icon: "heart.fill",
                    color: .red,
                    goal: nil,
                    current: nil
                )
            }
        }
    .padding()
    .cardStyle(baseColor: Color.mint, cornerRadius: 16)
    }
}

struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let goal: Double?
    let current: Double?
    
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
            
            if let goal = goal, let current = current {
                let progress = min(current / goal, 1.0)
                ProgressView(value: progress)
                    .tint(color)
                
                Text("\(Int(progress * 100))% of goal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    .padding()
    .cardStyle(baseColor: color.opacity(0.9), cornerRadius: 12)
    }
}

struct LatestGlucoseView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var latestGlucoseValue: Int? = nil
    @State private var latestGlucoseTimestamp: Date? = nil
    @State private var glucoseTrend: String? = nil
    @State private var isLoading: Bool = true

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

            if isLoading {
                // Show a compact loading skeleton while fetching
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonCard(height: 32, cornerRadius: 8)
                        SkeletonCard(height: 12, cornerRadius: 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let value = latestGlucoseValue {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(getGlucoseColor(value))
                            
                            if let trend = glucoseTrend {
                                Image(systemName: getTrendIcon(trend))
                                    .font(.title)
                                    .foregroundColor(getTrendColor(trend))
                            }
                        }
                        Text("mg/dL")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(getGlucoseStatusText(value))
                            .font(.headline)
                            .foregroundColor(getGlucoseColor(value))
                            .multilineTextAlignment(.trailing)
                        
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
                    
                    HStack {
                        Spacer()
                        
                        Image(systemName: "waveform.path.ecg")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.6))
                            
                        Spacer()
                    }
                }
            }
        }
    .padding()
    .cardStyle(baseColor: Color.pink, cornerRadius: 16)
        .task {
            await fetchLatestGlucose()
        }
    }

    private func fetchLatestGlucose() async {
        // Fetch data regardless of authorizationStatus; HealthKitManager returns
        // empty results when not available. This avoids UI hiding when read-only
        // permissions are present but write-status flags are inaccurate.
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            if let last = data.glucose.last {
                await MainActor.run {
                    self.latestGlucoseValue = Int(last.value)
                    self.latestGlucoseTimestamp = last.timestamp

                    // Simulate a trend based on recent values (in a real app, get this from CGM)
                    if data.glucose.count >= 2 {
                        let secondLast = data.glucose[data.glucose.count - 2]
                        let diff = last.value - secondLast.value
                        if diff > 10 {
                            self.glucoseTrend = "rising_quickly"
                        } else if diff > 3 {
                            self.glucoseTrend = "rising"
                        } else if diff < -10 {
                            self.glucoseTrend = "falling_quickly"
                        } else if diff < -3 {
                            self.glucoseTrend = "falling"
                        } else {
                            self.glucoseTrend = "stable"
                        }
                    }
                }
            }
        } catch {
            // No-op: keep nil to show placeholder
        }

        await MainActor.run {
            self.isLoading = false
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
    
    private func getGlucoseStatusText(_ value: Int) -> String {
        switch value {
        case 70...180: return "In Target Range"
        case 181...250: return "Above Target"
        case 251...: return "High"
        case ..<54: return "Urgently Low"
        case 54..<70: return "Below Target"
        default: return "Unknown"
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
                        healthKitManager.requestHealthKitPermissions()
                    }) {
                        Text("Sync HealthKit")
                            .font(.caption)
                    }
                    .buttonStyle(GradientButtonStyle(colors: [Color.green, Color.blue]))
                }
            }
        }
    .padding()
    .cardStyle(baseColor: Color.green, cornerRadius: 16)
    }
}

// MARK: - New Components

struct HealthKitActivitiesView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workouts: [HealthKitManagerWorkoutData] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
            
            if workouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No recent workouts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                ForEach(workouts.prefix(3), id: \.startDate) { workout in
                    WorkoutRow(workout: workout)
                    
                    if workout != workouts.prefix(3).last {
                        Divider()
                    }
                }
            }
        }
    .padding()
    .cardStyle(baseColor: Color.cyan, cornerRadius: 16)
        .task {
            await fetchWorkouts()
        }
    }
    
    private func fetchWorkouts() async {
        guard healthKitManager.authorizationStatus == .sharingAuthorized else { return }
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            await MainActor.run {
                self.workouts = data.workouts.sorted(by: { $0.startDate > $1.startDate })
            }
        } catch {
            // Handle error or keep empty array
        }
    }
}

struct WorkoutRow: View {
    let workout: HealthKitManagerWorkoutData
    
    var body: some View {
        HStack {
            Image(systemName: workoutIcon(for: workout.name))
                .font(.title3)
                .foregroundColor(workoutColor(for: workout.name))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(workoutColor(for: workout.name).opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(workout.duration / 60)) min • \(Int(workout.calories)) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(relativeTime(from: workout.startDate))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func workoutIcon(for name: String) -> String {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("run") {
            return "figure.run"
        } else if lowercasedName.contains("walk") {
            return "figure.walk"
        } else if lowercasedName.contains("cycle") || lowercasedName.contains("bike") {
            return "figure.outdoor.cycle"
        } else if lowercasedName.contains("swim") {
            return "figure.pool.swim"
        } else if lowercasedName.contains("yoga") {
            return "figure.mind.and.body"
        } else if lowercasedName.contains("strength") || lowercasedName.contains("train") {
            return "dumbbell"
        } else {
            return "figure.mixed.cardio"
        }
    }
    
    private func workoutColor(for name: String) -> Color {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("run") {
            return .green
        } else if lowercasedName.contains("walk") {
            return .blue
        } else if lowercasedName.contains("cycle") || lowercasedName.contains("bike") {
            return .orange
        } else if lowercasedName.contains("swim") {
            return .cyan
        } else if lowercasedName.contains("yoga") {
            return .purple
        } else if lowercasedName.contains("strength") || lowercasedName.contains("train") {
            return .red
        } else {
            return .indigo
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NutritionSummaryView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var nutritionData: HealthKitManagerNutritionData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Today")
                .font(.headline)
            
            if let nutrition = nutritionData {
                HStack(spacing: 16) {
                    NutrientRing(
                        value: "\(Int(nutrition.calories))",
                        label: "Calories",
                        color: .orange
                    )
                    
                    NutrientRing(
                        value: "\(Int(nutrition.carbs))g",
                        label: "Carbs",
                        color: .green
                    )
                    
                    NutrientRing(
                        value: "\(Int(nutrition.protein))g",
                        label: "Protein",
                        color: .blue
                    )
                    
                    NutrientRing(
                        value: "\(Int(nutrition.fat))g",
                        label: "Fat",
                        color: .red
                    )
                }
                .padding(.vertical, 8)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No nutrition data today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
        )
        .task {
            await fetchNutritionData()
        }
    }
    
    private func fetchNutritionData() async {
        guard healthKitManager.authorizationStatus == .sharingAuthorized else { return }
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            await MainActor.run {
                self.nutritionData = data.nutrition.first
            }
        } catch {
            // Handle error or keep nil
        }
    }
}

struct NutrientRing: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 64, height: 64)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                
                Text(value)
                    .font(.system(.callout, design: .rounded))
                    .bold()
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    title: "View Logs",
                    icon: "list.bullet.rectangle.fill",
                    color: .blue
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
                
                QuickActionButton(
                    title: "View Graphs",
                    icon: "chart.xyaxis.line",
                    color: .green
                ) {
                    selectedTab = 3
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    selectedTab = 5
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
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
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 8)
        }
        .buttonStyle(GradientButtonStyle(colors: [color, color.opacity(0.8)]))
    }
}
    
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(APIManager())
            .environmentObject(HealthKitManager())
    }
}

