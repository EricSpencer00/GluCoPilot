import SwiftUI
import HealthKit

struct DataSyncView: View {
    @EnvironmentObject private var healthManager: HealthKitManager
    @EnvironmentObject private var apiManager: APIManager
    @StateObject private var cache = CacheManager.shared
    @State private var isUploading = false
    @State private var insights: [APIManagerAIInsight] = []
    @State private var lastRun: Date?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple.gradient)

                    Text("AI Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Upload local logs and the last 24 hours of Health data to generate personalized AI recommendations")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Upload Button
                Button(action: uploadCache) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Text(isUploading ? "Generating Insights..." : "Upload & Generate Insights")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isUploading)
                .padding(.horizontal)
                
                // Last run info
                if let run = lastRun {
                    VStack(spacing: 8) {
                        Text("Last run: \(run.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !insights.isEmpty {
                            Text("Generated \(insights.count) insights")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Recent cached items (small preview)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Cached Logs (24h)")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(cache.getItems(since: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!)) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.type.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(item.payload.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
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
        .onAppear {
            // Request HealthKit permissions if not already granted
            if healthManager.authorizationStatus != .sharingAuthorized {
                healthManager.requestHealthKitPermissions()
            }
        }
    }
    
    private func syncData() {
            // Legacy sync function; not used in AI upload flow
        }

        private func uploadCache() {
            isUploading = true
            Task {
                do {
                    let healthData = try await healthManager.fetchLast24HoursData()
                    let nutritionSource = healthData.nutrition.first

                    let apiHealthData = APIManagerHealthData(
                        glucose: healthData.workouts.map { workout in
                            APIManagerGlucoseReading(
                                value: Int.random(in: 80...200), // placeholder for HealthKit glucose
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

                    let cached = cache.getItems(since: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!)
                    let aiInsights = try await apiManager.uploadCacheAndGenerateInsights(healthData: apiHealthData, cachedItems: cached)

                    await MainActor.run {
                        isUploading = false
                        lastRun = Date()
                        // Convert to APIManagerAIInsight for simple display
                        insights = aiInsights.map { ai in
                            APIManagerAIInsight(
                                title: ai.title,
                                description: ai.description,
                                type: "",
                                priority: "",
                                timestamp: ai.timestamp,
                                actionItems: ai.actionItems,
                                dataPoints: ai.dataPoints
                            )
                        }
                    }
                } catch {
                    await MainActor.run {
                        isUploading = false
                        errorMessage = "Failed to upload and generate insights: \(error.localizedDescription)"
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
        .background(Color(.systemBackground))
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
