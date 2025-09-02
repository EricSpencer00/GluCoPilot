import SwiftUI

struct APIRequestDebugView: View {
    @EnvironmentObject var apiManager: APIManager
    @State private var logs: [String] = []
    @State private var isRunning = false
    @State private var manualIdToken: String = ""

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

                // Debug: quick id_token exchange
                #if DEBUG
                VStack(spacing: 8) {
                    Text("Exchange Apple id_token with backend (debug)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Paste id_token here (optional)", text: $manualIdToken)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    HStack {
                        Button(action: { Task { await runIdTokenExchange() } }) {
                            Label("Exchange id_token", systemImage: "arrowshape.turn.up.right")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear Token") {
                            manualIdToken = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
                #endif

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
            let dummyWorkout = APIManagerWorkoutData(type: "DebugWalking", duration: 600, calories: 30, startDate: Date().addingTimeInterval(-3600), endDate: Date().addingTimeInterval(-3000))
            let dummyNutrition = APIManagerNutritionData(name: "DebugMeal", calories: 250, carbs: 30, protein: 10, fat: 8, timestamp: Date())

            let payload = APIManagerHealthData(glucose: [dummyGlucose], workouts: [dummyWorkout], nutrition: [dummyNutrition], timestamp: Date())
            let res = try await apiManager.syncHealthData(payload)
            append("syncHealthData -> glucose:\(res.glucoseReadings) workouts:\(res.workouts) nutrition:\(res.nutritionEntries)")
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

    #if DEBUG
    private func runIdTokenExchange() async {
        append("Starting id_token exchange...")
        guard let api = apiManager else {
            append("APIManager not available")
            return
        }

        let tokenToSend = manualIdToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KeychainHelper().getValue(for: "apple_id_token") : manualIdToken

        guard let token = tokenToSend else {
            append("No id_token available to send")
            return
        }

        do {
            let (access, refresh) = try await api.debugSendAppleIdToken(token, email: KeychainHelper().getValue(for: "user_email"), firstName: nil, lastName: nil)
            append("Exchange succeeded. access: \(access.prefix(20))... refresh: \(refresh?.prefix(20) ?? "nil")")
        } catch {
            append("Exchange failed: \(error.localizedDescription)")
        }
    }
    #endif
}

#Preview {
    APIRequestDebugView()
        .environmentObject(APIManager())
}
