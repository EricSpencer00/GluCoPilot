import SwiftUI
import HealthKit

struct DataSyncView: View {
    @EnvironmentObject private var healthManager: HealthKitManager
    @EnvironmentObject private var dexcomManager: DexcomManager
    @EnvironmentObject private var apiManager: APIManager
    @State private var isSyncing = false
    @State private var lastSyncDate: Date?
    @State private var syncResults: SyncResults?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDexcomSetup = false
    @State private var dexcomUsername = ""
    @State private var dexcomPassword = ""
    @State private var isInternational = false
    @State private var isConnectingDexcom = false
    @State private var dexcomErrorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green.gradient)
                    
                    Text("Data Sources")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect and manage your health data sources")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Data Sources
                VStack(spacing: 16) {
                    // HealthKit Card
                    Button(action: {
                        healthManager.requestHealthKitPermissions()
                    }) {
                        DataSourceCard(
                            icon: "heart.fill",
                            title: "Apple Health",
                            description: "Activity, steps, sleep, heart rate",
                            isAvailable: healthManager.isHealthKitAvailable,
                            isConnected: healthManager.authorizationStatus == .sharingAuthorized
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Dexcom Card
                    Button(action: {
                        showDexcomSetup = true
                    }) {
                        DataSourceCard(
                            icon: "drop.fill",
                            title: "Dexcom CGM",
                            description: "Continuous glucose monitoring data",
                            isAvailable: true,
                            isConnected: dexcomManager.isConnected
                        )
                    }
                    .buttonStyle(.plain)
                    
                    DataSourceCard(
                        icon: "fork.knife",
                        title: "MyFitnessPal",
                        description: "Nutrition and food logs (via Apple Health)",
                        isAvailable: healthManager.isHealthKitAvailable,
                        isConnected: healthManager.authorizationStatus == .sharingAuthorized
                    )
                }
                .padding(.horizontal)
                
                // Sync Button
                Button(action: syncData) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isSyncing ? "Syncing..." : "Sync Data")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSyncing)
                .padding(.horizontal)
                
                // Last Sync Info
                if let lastSync = lastSyncDate {
                    VStack(spacing: 8) {
                        Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let results = syncResults {
                            SyncResultsView(results: results)
                        }
                    }
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("To sync MyFitnessPal data:")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionStep(number: 1, text: "Open MyFitnessPal app")
                        InstructionStep(number: 2, text: "Go to More → Apps & Devices")
                        InstructionStep(number: 3, text: "Connect with Apple Health")
                        InstructionStep(number: 4, text: "Enable sharing for Nutrition data")
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sync Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showDexcomSetup) {
            DexcomSetupView(
                apiManager: apiManager,
                dexcomManager: dexcomManager,
                username: $dexcomUsername,
                password: $dexcomPassword,
                isInternational: $isInternational,
                isConnecting: $isConnectingDexcom,
                showError: $showError,
                errorMessage: $dexcomErrorMessage
            )
        }
        .onAppear {
            // Request HealthKit permissions if not already granted
            if healthManager.authorizationStatus != .sharingAuthorized {
                healthManager.requestHealthKitPermissions()
            }
        }
    }
    
    private func syncData() {
        isSyncing = true
        
        Task {
            do {
                // Fetch health data from HealthKit
                let healthData = try await healthManager.fetchLast24HoursData()
                
                // Convert HealthKitManagerHealthData to APIManagerHealthData
                let nutritionSource = healthData.nutrition.first

                let apiHealthData = APIManagerHealthData(
                    glucose: healthData.workouts.map { workout in
                        APIManagerGlucoseReading(
                            value: Int.random(in: 80...200), // Placeholder for now, will be replaced by actual Dexcom data
                            trend: "flat",
                            timestamp: workout.startDate,
                            unit: "mg/dL"
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
                
                // Sync data with backend
                let results = try await apiManager.syncHealthData(apiHealthData)
                
                // Convert APIManagerSyncResults to SyncResults
                let syncResults = SyncResults(
                    glucoseReadings: results.glucoseReadings,
                    workouts: results.workouts,
                    nutritionEntries: results.nutritionEntries,
                    errors: results.errors,
                    lastSyncDate: results.lastSyncDate
                )
                
                await MainActor.run {
                    isSyncing = false
                    lastSyncDate = Date()
                    self.syncResults = syncResults
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    errorMessage = "Failed to sync data: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct DataSourceCard: View {
    let icon: String
    let title: String
    let description: String
    let isAvailable: Bool
    var isConnected: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAvailable ? .blue : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isAvailable {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct DexcomSetupView: View {
    let apiManager: APIManager
    let dexcomManager: DexcomManager
    @Binding var username: String
    @Binding var password: String
    @Binding var isInternational: Bool
    @Binding var isConnecting: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Connect Dexcom")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter your Dexcom Share account credentials to sync your CGM data.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                            
                            TextField("Dexcom Share username", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                            
                            SecureField("Dexcom Share password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Toggle("Outside US (International)", isOn: $isInternational)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                        
                        Button(action: connectDexcom) {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Connect")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(username.isEmpty || password.isEmpty || isConnecting)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Connect Dexcom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Connection Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func connectDexcom() {
        isConnecting = true
        
        Task {
            do {
                try await dexcomManager.connect(
                    username: username,
                    password: password,
                    isInternational: isInternational,
                    apiManager: apiManager
                )
                
                await MainActor.run {
                    isConnecting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

struct SyncResultsView: View {
    let results: SyncResults
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Synced \(results.recordCount) records")
                .font(.caption)
                .foregroundStyle(.primary)
            
            if results.totalSyncedItems > 0 {
                Text("Glucose: \(results.glucoseReadings) • Workouts: \(results.workouts) • Nutrition: \(results.nutritionEntries)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        DataSyncView()
            .environmentObject(HealthKitManager())
    }
}
