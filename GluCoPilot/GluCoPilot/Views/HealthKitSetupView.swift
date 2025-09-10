import SwiftUI
import UIKit

struct HealthKitSetupView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isRequesting = false
    @State private var requestResult: String? = nil
    @State private var nutritionReport: [String]? = nil
    @State private var foodItemsReport: [[String: Any]]? = nil
    let onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red.gradient)

            Text("Connect Apple Health")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("To provide personalized insights we need permission to read your health data (steps, heart rate, sleep, and blood glucose). This data stays on your device and is only shared with your permission.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if let result = requestResult {
                Text(result)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Show any HealthKit authorization error messages for diagnostics
            if let authErr = healthKitManager.lastAuthorizationErrorMessage {
                Text("Debug: \(authErr)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: requestPermissions) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isRequesting ? "Requesting…" : "Connect Apple Health")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle(colors: [Color.red, Color.pink]))
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.horizontal)

            // Developer-friendly safe request button to avoid system-gesture timing issues.
            Button(action: requestPermissionsSafe) {
                Text("Request now (safe)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            // Minimal request for debugging: only ask for blood glucose
            Button(action: {
                isRequesting = true
                requestResult = "Requesting minimal HealthKit permissions..."
                Task {
                    await MainActor.run {
                        healthKitManager.requestHealthKitPermissionsMinimal()
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        isRequesting = false
                        requestResult = "Minimal permission request sent"
                    }
                }
            }) {
                Text("Request minimal (blood glucose only)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            // If the auth flow requires HealthKit, do not allow skipping.
            if authManager.requiresHealthKitAuthorization {
                Text("Health data permission is required to continue.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Button(action: skip) {
                    Text("Skip for now")
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }

            // Diagnostic controls
            Button(action: runDiagnostics) {
                Text("Run Diagnostics")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .padding(.horizontal)

            // Quick-check: list nutrition sources and recent food correlations
            Button(action: fetchNutritionSources) {
                Text("Check Nutrition Sources")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: fetchRecentFood) {
                Text("Fetch Recent Food Records")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: fetchRecentFoodItems) {
                Text("Fetch Structured Food Items")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            // Workouts: fetch & save
            Button(action: fetchRecentWorkouts) {
                Text("Fetch Recent Workouts (24h)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: saveWorkoutsToLocal) {
                Text("Save Recent Workouts Locally")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: showSavedWorkoutsCount) {
                Text("Show Saved Workout Count")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: saveFoodItemsToLocal) {
                Text("Save Fetched Items Locally")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            Button(action: showSavedCount) {
                Text("Show Saved Food Count")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .padding(.horizontal)

            if let report = healthKitManager.debugReport {
                ScrollView {
                    Text(report)
                        .font(.caption)
                        .padding()
                }
                .frame(maxHeight: 240)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            if let nutrition = nutritionReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(nutrition.indices, id: \.self) { i in
                            Text(nutrition[i])
                                .font(.caption2)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 240)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            if let items = foodItemsReport {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items.indices, id: \.self) { idx in
                            let item = items[idx]
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item["name"] as? String ?? "Food") — \(String(describing: item["timestamp"]))")
                                    .font(.caption)
                                    .bold()
                                Text("cal: \(String(format: "%.0f", item["caloriesKcal"] as? Double ?? 0)) kcal • carbs: \(String(format: "%.1f", item["carbsGrams"] as? Double ?? 0)) g • protein: \(String(format: "%.1f", item["proteinGrams"] as? Double ?? 0)) g • fat: \(String(format: "%.1f", item["fatGrams"] as? Double ?? 0)) g")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 240)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Small saved items indicator
            if let result = requestResult, result.contains("saved") || result.contains("count") {
                Text(result)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let result = requestResult, result.contains("not granted") {
                Button(action: openSettings) {
                    Text("Open Settings")
                }
            }

            Spacer()
        }
        .padding()
    .withTopGradient()
    }

    private func requestPermissions() {
        isRequesting = true
        requestResult = nil

        // Request permissions and then update result
        Task {
            // Directly request permissions - don't try to validate first
            // This ensures the iOS permission dialog will always show
            await MainActor.run {
                healthKitManager.requestHealthKitPermissions()
            }

            // Poll briefly for change in authorization status (HealthKit callbacks can be async)
            var attempts = 0
            while attempts < 8 { // Increase poll attempts
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                attempts += 1
                
                // Check authorizationStatus directly (don't use validatePermissionStatus here)
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    break
                }
            }

            await MainActor.run {
                isRequesting = false
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    requestResult = "Permissions granted \u{2014} syncing data..."
                    // Fetch initial properties
                    Task {
                        healthKitManager.startObservingAndRefresh()
                        await healthKitManager.updatePublishedProperties()
                        onComplete?()
                    }
                } else {
                    requestResult = "Permissions not granted. You can enable them in Settings to access full features."
                }
            }
        }
    }

    /// A safe permission request triggered by user tap that waits briefly before calling
    /// HealthKit authorization to avoid system UI/gesture suppression. Polls status like
    /// the main requestPermissions flow and updates `requestResult`.
    private func requestPermissionsSafe() {
        isRequesting = true
        requestResult = nil

        Task {
            // Small delay to avoid system gesture UI interference
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            await MainActor.run {
                healthKitManager.requestHealthKitPermissions()
            }

            // Poll briefly for change in authorization status
            var attempts = 0
            while attempts < 10 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                attempts += 1
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    break
                }
            }

            await MainActor.run {
                isRequesting = false
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    requestResult = "Permissions granted syncing data"
                    Task {
                        healthKitManager.startObservingAndRefresh()
                        await healthKitManager.updatePublishedProperties()
                        onComplete?()
                    }
                } else if let authErr = healthKitManager.lastAuthorizationErrorMessage {
                    requestResult = "Permissions not granted: \(authErr)"
                } else {
                    requestResult = "Permissions not granted. You can enable them in Settings to access full features."
                }
            }
        }
    }

    private func runDiagnostics() {
        requestResult = "Running diagnostics..."
        Task {
            await healthKitManager.runDiagnostics()
            await MainActor.run {
                requestResult = "Diagnostics complete"
            }
        }
    }

    private func skip() {
        onComplete?()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func fetchNutritionSources() {
        requestResult = "Fetching nutrition sources..."
        nutritionReport = nil
        Task {
            let sources = await healthKitManager.fetchSourcesReportAll()
            await MainActor.run {
                nutritionReport = sources
                requestResult = "Nutrition sources fetched"
            }
        }
    }

    private func fetchRecentFood() {
        requestResult = "Fetching recent food records..."
        nutritionReport = nil
        Task {
            let items = await healthKitManager.fetchRecentFoodCorrelations()
            await MainActor.run {
                nutritionReport = items
                requestResult = "Recent food records fetched"
            }
        }
    }

    private func fetchRecentFoodItems() {
        requestResult = "Fetching structured food items..."
        foodItemsReport = nil
        Task {
            let items = await healthKitManager.fetchRecentFoodItems()
            await MainActor.run {
                foodItemsReport = items
                requestResult = "Structured food items fetched"
            }
        }
    }

    private func saveFoodItemsToLocal() {
        requestResult = "Saving fetched items locally..."
        Task {
            let saved = await healthKitManager.saveFetchedFoodItemsToLocalStore()
            await MainActor.run {
                requestResult = "Saved \(saved) food items locally"
            }
        }
    }

    private func showSavedCount() {
        let saved = healthKitManager.getSavedFoodItems().count
        requestResult = "Saved food items: \(saved)"
    }

    private func fetchRecentWorkouts() {
        requestResult = "Fetching recent workouts..."
        Task {
            let items = await healthKitManager.fetchRecentWorkouts()
            await MainActor.run {
                // Convert to string list for quick UI display
                let lines = items.map { item -> String in
                    let start = item["startDate"] as? Date
                    let type = item["type"] as? String ?? "Workout"
                    let dur = item["durationMinutes"] as? Double ?? 0
                    let cal = item["caloriesKcal"] as? Double ?? 0
                    return "\(type) \(start.map { String(describing: $0) } ?? "") — \(String(format: "%.0f", cal)) kcal • \(String(format: "%.1f", dur)) min"
                }
                nutritionReport = lines
                requestResult = "Recent workouts fetched"
            }
        }
    }

    private func saveWorkoutsToLocal() {
        requestResult = "Saving workouts locally..."
        Task {
            let saved = await healthKitManager.saveFetchedWorkoutsToLocalStore()
            await MainActor.run {
                requestResult = "Saved \(saved) workouts locally"
            }
        }
    }

    private func showSavedWorkoutsCount() {
        let saved = healthKitManager.getSavedWorkouts().count
        requestResult = "Saved workouts: \(saved)"
    }
}

#Preview {
    HealthKitSetupView()
}
