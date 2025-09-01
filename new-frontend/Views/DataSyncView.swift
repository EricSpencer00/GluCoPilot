import SwiftUI
import HealthKit

struct DataSyncView: View {
    @EnvironmentObject var healthManager: HealthKitManager
    @EnvironmentObject var apiManager: APIManager
    @State private var isSyncing = false
    @State private var lastSyncDate: Date?
    @State private var syncResults: SyncResults?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green.gradient)
                    
                    Text("Data Sync")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Import health data from the last 24 hours to enhance your AI insights")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Data Sources
                VStack(spacing: 16) {
                    DataSourceCard(
                        icon: "heart.fill",
                        title: "Apple Health",
                        description: "Activity, steps, sleep, heart rate",
                        isAvailable: healthManager.isHealthKitAvailable
                    )
                    
                    DataSourceCard(
                        icon: "fork.knife",
                        title: "MyFitnessPal",
                        description: "Nutrition and food logs (via Apple Health)",
                        isAvailable: healthManager.isHealthKitAvailable
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
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Data Sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sync Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func syncData() {
        isSyncing = true
        
        Task {
            do {
                let healthData = try await healthManager.fetchLast24HoursData()
                let results = try await apiManager.syncHealthData(healthData)
                
                await MainActor.run {
                    isSyncing = false
                    lastSyncDate = Date()
                    syncResults = results
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    errorMessage = error.localizedDescription
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
            
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isAvailable ? .green : .red)
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
            
            if results.recordCount > 0 {
                Text("Steps: \(results.stepCount) • Workouts: \(results.workoutCount) • Sleep: \(results.sleepHours, specifier: "%.1f")h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct SyncResults {
    let recordCount: Int
    let stepCount: Int
    let workoutCount: Int
    let sleepHours: Double
}

#Preview {
    NavigationStack {
        DataSyncView()
            .environmentObject(HealthKitManager())
            .environmentObject(APIManager())
    }
}
