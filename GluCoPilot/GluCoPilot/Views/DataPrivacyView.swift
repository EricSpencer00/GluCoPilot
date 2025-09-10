import SwiftUI

struct DataPrivacyView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showingDeleteConfirmation = false
    @State private var exportInProgress = false
    @State private var exportSuccess = false
    @State private var exportError = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    
    var body: some View {
        List {
            Section(header: Text("Data Collection")) {
                NavigationLink(destination: StaticDocumentView(title: "Privacy Policy", content: StaticDocumentView.privacyPlaceholder)) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }
                
                NavigationLink(destination: HealthDataAccessView()) {
                    Label("Health Data Access", systemImage: "heart.text.square")
                }
            }
            
            Section(header: Text("Your Data"), footer: Text("View what data has been collected from your device.")) {
                NavigationLink(destination: CollectedDataSummaryView()) {
                    Label("View Collected Data", systemImage: "list.bullet.clipboard")
                }
            }
            
            Section(header: Text("Data Controls")) {
                Button(action: { exportData() }) {
                    HStack {
                        Label("Export Your Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if exportInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(exportInProgress)
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Consent Management")) {
                Toggle("Health Data Collection", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "hasConsentedToDataCollection") },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "hasConsentedToDataCollection")
                        if !newValue {
                            // If user withdraws consent, stop data collection
                            healthKitManager.stopObservingHealthData()
                        } else {
                            // If user gives consent, restart data collection
                            healthKitManager.startObservingAndRefresh()
                        }
                    }
                ))
                
                Button(action: {
                    // Show consent view again
                    showConsentAgain()
                }) {
                    Text("Review Consent Agreements")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Data & Privacy")
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete All Data"),
                message: Text("Are you sure you want to delete all your data? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAllData()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Data Export", isPresented: $exportSuccess) {
            Button("Share") {
                if shareURL != nil { showShareSheet = true }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data export is ready.")
        }
        .alert("Export Failed", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There was a problem exporting your data. Please try again later.")
        }
    }
    
    private func exportData() {
        exportInProgress = true
        Task {
            do {
                // Gather recent data (last 30 days) from HealthKit and local cache
                let end = Date()
                let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? Date(timeIntervalSinceNow: -30*24*3600)
                let hk = try await healthKitManager.fetchLast24HoursData() // minimal for MVP

                // Build JSON object
                var payload: [String: Any] = [:]
                payload["exported_at"] = ISO8601DateFormatter().string(from: Date())
                payload["glucose"] = hk.glucose.map { s in
                    [
                        "value": s.value,
                        "unit": s.unit,
                        "timestamp": ISO8601DateFormatter().string(from: s.timestamp)
                    ]
                }
                payload["workouts"] = hk.workouts.map { w in
                    [
                        "name": w.name,
                        "duration": w.duration,
                        "calories": w.calories,
                        "startDate": ISO8601DateFormatter().string(from: w.startDate),
                        "endDate": ISO8601DateFormatter().string(from: w.endDate)
                    ]
                }
                payload["nutrition"] = hk.nutrition.map { n in
                    [
                        "name": n.name,
                        "calories": n.calories,
                        "carbs": n.carbs,
                        "protein": n.protein,
                        "fat": n.fat,
                        "timestamp": ISO8601DateFormatter().string(from: n.timestamp)
                    ]
                }
                payload["steps_today"] = hk.steps
                payload["activeCalories_today"] = hk.activeCalories
                payload["avgHeartRate_today"] = hk.averageHeartRate
                payload["sleepHours_today"] = hk.sleepHours

                // Include locally cached log items
                let cached = CacheManager.shared.getItems(since: start)
                payload["cached_items"] = cached.map { item in
                    [
                        "id": item.id.uuidString,
                        "type": item.type,
                        "payload": item.payload,
                        "timestamp": ISO8601DateFormatter().string(from: item.timestamp)
                    ] as [String: Any]
                }

                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
                let tmp = FileManager.default.temporaryDirectory
                let url = tmp.appendingPathComponent("glucopilot-export-\(Int(Date().timeIntervalSince1970)).json")
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    self.shareURL = url
                    self.exportSuccess = true
                    self.exportInProgress = false
                }
            } catch {
                await MainActor.run {
                    self.exportError = true
                    self.exportInProgress = false
                }
            }
        }
    }
    
    private func deleteAllData() {
        // Best-effort local cleanup for MVP
        CacheManager.shared.clearAll()
        healthKitManager.resetAllHealthKitState()
        UserDefaults.standard.removeObject(forKey: "hasConsentedToDataCollection")
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedLimitedFunctionality")
    }
    
    private func showConsentAgain() {
        // Mark onboarding steps incomplete so the app routes user through consent/onboarding again
        UserDefaults.standard.set(false, forKey: "hasCompletedMedicalDisclaimer")
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}

struct HealthDataAccessView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        List {
            Section(header: Text("Health Data Access")) {
                dataTypeRow(title: "Blood Glucose", isAccessed: true)
                dataTypeRow(title: "Heart Rate", isAccessed: true)
                dataTypeRow(title: "Step Count", isAccessed: true)
                dataTypeRow(title: "Sleep Analysis", isAccessed: true)
                dataTypeRow(title: "Workouts", isAccessed: true)
                dataTypeRow(title: "Dietary Information", isAccessed: true)
            }
            
            Section(header: Text("Manage Permissions")) {
                Button(action: {
                    openHealthAppSettings()
                }) {
                    Text("Manage in Health App")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    healthKitManager.requestHealthKitPermissions()
                }) {
                    Text("Review Permissions")
                        .foregroundColor(.blue)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Health Data Access")
    }
    
    private func dataTypeRow(title: String, isAccessed: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isAccessed {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func openHealthAppSettings() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

struct CollectedDataSummaryView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var glucoseCount24h: Int = 0
    @State private var workoutCount24h: Int = 0
    @State private var hasStepsToday: Bool = false
    @State private var hasHeartRateToday: Bool = false
    @State private var nutritionItems24h: Int = 0
    @State private var sleepHours24h: Double = 0
    @State private var loadError: String? = nil
    
    var body: some View {
        List {
            Section(header: Text("Glucose Data")) {
                Text("Last 24 hours: \(glucoseCount24h) readings")
                if let err = loadError {
                    Text("Note: \(err)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Activity Data")) {
                Text("Last 24 hours: \(workoutCount24h) workouts")
                Text(hasStepsToday ? "Step count: available today" : "Step count: not available today")
            }
            
            Section(header: Text("Food Entries")) {
                Text("Last 24 hours: \(nutritionItems24h) entries")
            }
            
            Section(header: Text("Other Health Data")) {
                Text(String(format: "Sleep (last 24h): %.1f hours", sleepHours24h))
                Text(hasHeartRateToday ? "Heart rate: available today" : "Heart rate: not available today")
            }
            
            Section(header: Text("Note")) {
                Text("This is a summary of data available to GluCoPilot through Apple HealthKit. No data is stored permanently on our servers. Data is processed transiently to generate insights and recommendations.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Your Data Summary")
        .task {
            await loadCounts()
        }
    }

    private func loadCounts() async {
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            glucoseCount24h = data.glucose.count
            workoutCount24h = data.workouts.count
            hasStepsToday = data.steps > 0
            hasHeartRateToday = data.averageHeartRate > 0
            nutritionItems24h = data.nutrition.count
            sleepHours24h = data.sleepHours
            loadError = nil
        } catch {
            loadError = "Health data not available or not authorized"
        }
    }
}

struct DataPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DataPrivacyView()
                .environmentObject(HealthKitManager())
        }
    }
}
