import SwiftUI

struct APIRequestDebugView: View {
    @EnvironmentObject var apiManager: APIManager
    @State private var logs: [String] = []
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button(action: { Task { await runAllTests() } }) {
                        Label("Run API Smoke Tests", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)

                    Button("Clear") {
                        logs.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(logs, id: \ .self) { line in
                            Text(line)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("API Debug")
        }
    }

    private func append(_ text: String) {
        Task { @MainActor in
            logs.append(text)
        }
    }

    private func runAllTests() async {
        guard !isRunning else { return }
        await MainActor.run { isRunning = true }
        append("Starting API smoke tests...")

        // 1) Test generateInsights (aggregate)
        append("Calling aggregateDataAndGenerateInsights()...")
        do {
            let insights = try await apiManager.aggregateDataAndGenerateInsights()
            append("aggregateDataAndGenerateInsights -> returned \(insights.count) insights")
        } catch {
            append("aggregateDataAndGenerateInsights -> error: \(error.localizedDescription)")
        }

        // 2) Test syncHealthData with minimal payload
        append("Calling syncHealthData with minimal payload...")
        do {
            let dummyGlucose = APIManagerGlucoseReading(value: 120, trend: "flat", timestamp: Date(), unit: "mg/dL")
            let dummyWorkout = APIManagerWorkoutData(
                type: "DebugWalking",
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date().addingTimeInterval(-3000),
                duration: 600,
                caloriesBurned: 30,
                distance: 0,
                steps: 0
            )
            let dummyNutrition = APIManagerNutritionData(
                name: "DebugMeal",
                timestamp: Date(),
                calories: 250,
                carbs: 30,
                protein: 10,
                fat: 8
            )

            let metrics = APIManagerHealthMetrics(steps: 0, activeCalories: 0, heartRate: 0, glucose: Double(dummyGlucose.value))
            let sleep = APIManagerSleepData(totalHours: 0, deepSleepHours: 0, remSleepHours: 0)

            let payload = APIManagerHealthData(
                platform: "apple_health",
                timestamp: Date(),
                metrics: metrics,
                workouts: [dummyWorkout],
                sleepData: sleep,
                nutrition: [dummyNutrition]
            )

            let res = try await apiManager.syncHealthData(payload)
            append("syncHealthData -> workouts:\(res.workouts) nutrition:\(res.nutritionEntries) steps:\(res.steps) sleep:\(res.sleep)")
        } catch {
            append("syncHealthData -> error: \(error.localizedDescription)")
        }

        // 3) Test Dexcom validate (if you want, this will fail without valid creds)
        append("Calling validateDexcomCredentials with placeholder creds (expected to fail unless valid)...")
        do {
            let ok = try await apiManager.validateDexcomCredentials(username: "test@example.com", password: "password", isInternational: false)
            append("validateDexcomCredentials -> ok:\(ok)")
        } catch {
            append("validateDexcomCredentials -> error: \(error.localizedDescription)")
        }

        append("API smoke tests finished")
        await MainActor.run { isRunning = false }
    }
}

#Preview {
    APIRequestDebugView()
        .environmentObject(APIManager())
}
