import SwiftUI

struct APIRequestDebugView: View {
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var healthKitManager: HealthKitManager
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

                    Button(action: { Task { await fetchHealthKitDebug() } }) {
                        Label("Fetch HealthKit Data", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { Task { await fetchGlucoseSamplesDebug() } }) {
                        Label("Dump Glucose Samples", systemImage: "drop.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { Task { await runAuthAndAnySampleChecks() } }) {
                        Label("Auth & Any-Glucose Check", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.bordered)

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

    private func fetchHealthKitDebug() async {
        append("Fetching HealthKit last 24h data...")
        do {
            let data = try await healthKitManager.fetchLast24HoursData()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            if let jsonStr = String(data: jsonData, encoding: .utf8) {
                append("HealthKit payload: \n\(jsonStr)")
            } else {
                append("HealthKit payload: <failed to stringify>")
            }
        } catch {
            append("HealthKit fetch error: \(error.localizedDescription)")
        }
    }

    private func fetchGlucoseSamplesDebug() async {
        append("Dumping recent glucose samples (detailed)...")
        do {
            let lines = try await healthKitManager.fetchRecentGlucoseSamples(limit: 200)
            if lines.isEmpty {
                append("No glucose samples returned from HealthKit (empty array)")
            } else {
                for l in lines {
                    append(l)
                }
            }
        } catch {
            append("Glucose dump failed: \(error.localizedDescription)")
        }
    }

    private func runAuthAndAnySampleChecks() async {
        append("Running authorization status report...")
        let report = healthKitManager.getAuthorizationStatusReport()
        for r in report { append(r) }

        append("Running permissive glucose sample query (no predicate)...")
        do {
            let any = try await healthKitManager.fetchAnyGlucoseSamples(limit: 200)
            if any.isEmpty {
                append("No samples returned by permissive query")
            } else {
                append("Permissive query returned \(any.count) samples")
                for l in any.prefix(20) { append(l) }
            }
        } catch {
            append("Permissive glucose query error: \(error.localizedDescription)")
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

        // 1) Test generateInsights with sample health payload
        append("Calling generateInsights(healthData:prompt:) with sample payload...")
        do {
            let dummyGlucose = APIManagerGlucoseReading(value: 120, trend: "flat", timestamp: Date(), unit: "mg/dL")
            let dummyWorkout = APIManagerWorkoutData(type: "DebugWalking", duration: 600, calories: 30, startDate: Date().addingTimeInterval(-3600), endDate: Date().addingTimeInterval(-3000))
            let dummyNutrition = APIManagerNutritionData(name: "DebugMeal", calories: 250, carbs: 30, protein: 10, fat: 8, timestamp: Date())

            let sampleHealth = APIManagerHealthData(glucose: [dummyGlucose], workouts: [dummyWorkout], nutrition: [dummyNutrition], timestamp: Date())

            let insights = try await apiManager.generateInsights(healthData: sampleHealth, prompt: "Debug: smoke test")
            append("generateInsights -> returned \(insights.count) insights")
        } catch {
            // Provide extra clues for common server responses
            let msg = error.localizedDescription
            append("generateInsights -> error: \(msg)")
            if msg.lowercased().contains("unauthorized") {
                append("Hint: server returned 401/403. Are your tokens set in keychain or does the server accept stateless requests?")
            }
            if msg.lowercased().contains("not found") || msg.contains("404") {
                append("Hint: endpoint not available (404). The backend may have DEBUG=false; debug-only endpoints will be 404.")
            }
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

        // 3) Legacy Dexcom validate (Dexcom integration removed; this is a legacy call and will usually fail)
        append("Calling legacy validateDexcomCredentials (Dexcom removed) — expected to fail in most environments...")
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
    let api = apiManager

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
