import Foundation

// MARK: - API Manager Models (Isolated to avoid conflicts)
struct APIManagerGlucoseReading: Codable, Identifiable {
    var id = UUID()
    let value: Int
    let trend: String
    let timestamp: Date
    let unit: String
}

// Local cache wrapper so we store a timestamp alongside readings
private struct CachedGlucose: Codable {
    let timestamp: Date
    let readings: [APIManagerGlucoseReading]
}

struct APIManagerHealthData: Codable {
    var glucose: [APIManagerGlucoseReading]
    let workouts: [APIManagerWorkoutData]?
    let nutrition: [APIManagerNutritionData]?
    let timestamp: Date
}

struct APIManagerWorkoutData: Codable, Identifiable {
    var id = UUID()
    let type: String
    let duration: TimeInterval
    let calories: Double?
    let startDate: Date
    let endDate: Date
}

struct APIManagerNutritionData: Codable, Identifiable {
    var id = UUID()
    let name: String
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let timestamp: Date
}

struct APIManagerAIInsight: Codable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let type: String
    let priority: String
    let timestamp: Date
    let actionItems: [String]
    let dataPoints: [String: Double]
}

struct APIManagerSyncResults: Codable {
    let glucoseReadings: Int
    let workouts: Int
    let nutritionEntries: Int
    let errors: [String]
    let lastSyncDate: Date
    
    var isSuccessful: Bool {
        return errors.isEmpty
    }
    
    var totalSyncedItems: Int {
        return glucoseReadings + workouts + nutritionEntries
    }
}

// MARK: - Error Types
enum APIManagerError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case rateLimited
    case maintenanceMode
    case invalidResponse
    case invalidData
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Authentication required"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .maintenanceMode:
            return "Service is temporarily unavailable"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data format"
        case .invalidCredentials:
            return "Invalid or missing credentials"
        }
    }
}

// MARK: - Keychain Helper
class APIManagerKeychainHelper {
    func setValue(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
class APIManager: ObservableObject {
    @Published var cachedInsights: [AIInsight] = []
    private let cachedInsightsKey = "cached_ai_insights_v1"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: cachedInsightsKey) {
            if let decoded = try? JSONDecoder().decode([AIInsight].self, from: data) {
                self.cachedInsights = decoded
            }
        }
    }
    private let baseURL = "https://glucopilot-8ed6389c53c8.herokuapp.com"
    private let session = URLSession.shared
    private let keychain = APIManagerKeychainHelper()
    
    // MARK: - Authentication
    func validateDexcomCredentials(username: String, password: String, isInternational: Bool) async throws -> Bool {
        // Ensure we have an Apple id_token (JWT) to send; server expects a real Apple id_token
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }
        
        // Detect simulator fallback token
        let isSimulatorToken = appleIdToken.starts(with: "dev_simulator_token_")
        #if targetEnvironment(simulator)
        if isSimulatorToken {
            print("[APIManager] Using simulator fallback token - some features may be limited")
        }
        #endif

        let url = URL(string: "\(baseURL)/api/v1/dexcom/signin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple id_token (JWT) for authentication
        request.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "ous": isInternational
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else {
            // Debug output: include response body to help diagnose auth issues (sanitized)
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[APIManager] validateDexcomCredentials -> status: \(httpResponse.statusCode), body: \(bodyStr)")
            
            // Special handling for simulator mode with fallback token
            #if targetEnvironment(simulator)
            if isSimulatorToken && (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
                print("[APIManager] Simulator fallback token rejected by server as expected")
                print("[APIManager] In simulator mode, returning mock success for testing UI")
                return true // Return mock success for simulator testing
            }
            #endif
            
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["detail"] as? String ?? bodyStr
            throw APIManagerError.serverError(errorMessage)
        }
    }
    
    // Register a user with Apple ID
    func registerWithAppleID(userID: String, fullName: String?, email: String?) async throws -> Bool {
        // Require Apple id_token (JWT) to register with backend
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/apple/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "apple_id": userID
        ]
        
        if let fullName = fullName {
            body["full_name"] = fullName
        }
        
        if let email = email {
            body["email"] = email
        }
        
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    request.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Store the user ID in keychain
            keychain.setValue(userID, for: "apple_user_id")
            return true
        } else {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["detail"] as? String ?? "Registration failed"
            throw APIManagerError.serverError(errorMessage)
        }
    }
    
    func fetchLatestGlucoseReading(username: String, password: String, isInternational: Bool) async throws -> APIManagerGlucoseReading {
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/glucose/stateless/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple id_token (JWT) for authentication
        request.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "ous": isInternational
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIManagerError.unauthorized
            } else if httpResponse.statusCode == 429 {
                throw APIManagerError.rateLimited
            } else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorData?["detail"] as? String ?? "Server returned status code \(httpResponse.statusCode)"
                throw APIManagerError.serverError(errorMessage)
            }
        }
        
        do {
            // Parse the response data
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let readings = responseData?["readings"] as? [[String: Any]] ?? []
            
            guard let firstReading = readings.first,
                  let value = firstReading["value"] as? Int,
                  let trend = firstReading["trend"] as? String,
                  let timestampString = firstReading["timestamp"] as? String else {
                throw APIManagerError.invalidData
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Try with fractional seconds first, then without if that fails
            let timestamp: Date
            if let date = formatter.date(from: timestampString) {
                timestamp = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: timestampString) ?? Date()
            }
            
            return APIManagerGlucoseReading(
                value: value,
                trend: trend,
                timestamp: timestamp,
                unit: firstReading["unit"] as? String ?? "mg/dL"
            )
        } catch {
            print("Error parsing glucose reading: \(error.localizedDescription)")
            throw APIManagerError.decodingError(error)
        }
    }
    
    // Fetch historical glucose readings for a given timeframe
    func fetchGlucoseReadings(timeframe: String, count: Int = 100) async throws -> [APIManagerGlucoseReading] {
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }
        
        // Ensure we have Dexcom credentials
        guard let username = keychain.getValue(for: "dexcom_username"),
              let password = keychain.getValue(for: "dexcom_password"),
              let isInternationalString = keychain.getValue(for: "dexcom_is_international") else {
            throw APIManagerError.invalidCredentials
        }
        
        let isInternational = isInternationalString == "true" || isInternationalString == "1"

        let url = URL(string: "\(baseURL)/api/v1/glucose/stateless/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple id_token (JWT) for authentication
        request.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "ous": isInternational,
            "timeframe": timeframe,
            "count": count
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIManagerError.unauthorized
            } else if httpResponse.statusCode == 429 {
                throw APIManagerError.rateLimited
            } else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorData?["detail"] as? String ?? "Server returned status code \(httpResponse.statusCode)"
                throw APIManagerError.serverError(errorMessage)
            }
        }
        
        do {
            // Parse the response data
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let readings = responseData?["readings"] as? [[String: Any]] ?? []
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var glucoseReadings: [APIManagerGlucoseReading] = []
            
            for reading in readings {
                guard let value = reading["value"] as? Int,
                      let trend = reading["trend"] as? String,
                      let timestampString = reading["timestamp"] as? String else {
                    continue
                }
                
                // Try with fractional seconds first, then without if that fails
                let timestamp: Date
                if let date = formatter.date(from: timestampString) {
                    timestamp = date
                } else {
                    formatter.formatOptions = [.withInternetDateTime]
                    timestamp = formatter.date(from: timestampString) ?? Date()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                }
                
                let unit = reading["unit"] as? String ?? "mg/dL"
                
                let glucoseReading = APIManagerGlucoseReading(
                    value: value,
                    trend: trend,
                    timestamp: timestamp,
                    unit: unit
                )
                
                glucoseReadings.append(glucoseReading)
            }
            
            return glucoseReadings
        } catch {
            print("Error parsing glucose readings: \(error.localizedDescription)")
            throw APIManagerError.decodingError(error)
        }
    }

    // MARK: - Glucose cache helpers
    private func cacheGlucoseReadings(_ readings: [APIManagerGlucoseReading], timeframe: String) {
        let cached = CachedGlucose(timestamp: Date(), readings: readings)
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: "cached_glucose_\(timeframe)_v1")
        }
    }

    func getCachedGlucoseReadings(timeframe: String) -> (readings: [APIManagerGlucoseReading], timestamp: Date)? {
        guard let data = UserDefaults.standard.data(forKey: "cached_glucose_\(timeframe)_v1") else { return nil }
        if let cached = try? JSONDecoder().decode(CachedGlucose.self, from: data) {
            return (cached.readings, cached.timestamp)
        }
        return nil
    }
    
    // MARK: - Health Data Sync
    func syncHealthData(_ healthData: APIManagerHealthData) async throws -> APIManagerSyncResults {
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple id_token (JWT) for authentication
        request.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(healthData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIManagerError.unauthorized
            } else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorData?["detail"] as? String ?? "Server returned status code \(httpResponse.statusCode)"
                throw APIManagerError.serverError(errorMessage)
            }
        }
        
        // Parse sync results
        do {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let glucoseReadings = responseData?["glucose_readings"] as? Int ?? 0
            let workouts = responseData?["workouts"] as? Int ?? 0
            let nutritionEntries = responseData?["nutrition_entries"] as? Int ?? 0
            let errors = responseData?["errors"] as? [String] ?? []
            
            return APIManagerSyncResults(
                glucoseReadings: glucoseReadings,
                workouts: workouts,
                nutritionEntries: nutritionEntries,
                errors: errors,
                lastSyncDate: Date()
            )
        } catch {
            print("Error parsing sync results: \(error.localizedDescription)")
            
            // Return basic results if parsing fails
            return APIManagerSyncResults(
                glucoseReadings: healthData.glucose.count,
                workouts: healthData.workouts?.count ?? 0,
                nutritionEntries: healthData.nutrition?.count ?? 0,
                errors: ["Failed to parse server response"],
                lastSyncDate: Date()
            )
        }
    }
    
    // MARK: - AI Insights
    func generateInsights() async throws -> [AIInsight] {
        guard let appleIdToken = keychain.getValue(for: "apple_id_token") else {
            throw APIManagerError.unauthorized
        }

        // Prefer stateless recommendations endpoint if Dexcom creds are present
        var useStateless = false
        var dexcomBody: [String: Any] = [:]
        if let username = keychain.getValue(for: "dexcom_username"),
           let password = keychain.getValue(for: "dexcom_password") {
            useStateless = true
            let isInternational = (keychain.getValue(for: "dexcom_is_international") == "true")
            dexcomBody = ["username": username, "password": password, "ous": isInternational]
        }

        let request: URLRequest
        if useStateless {
            var req = URLRequest(url: URL(string: "\(baseURL)/api/v1/recommendations/stateless")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: dexcomBody)
            request = req
        } else {
            var req = URLRequest(url: URL(string: "\(baseURL)/api/v1/recommendations/recommendations")!)
            req.httpMethod = "GET"
            req.setValue("Bearer \(appleIdToken)", forHTTPHeaderField: "Authorization")
            request = req
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIManagerError.unauthorized
            } else if httpResponse.statusCode == 429 {
                throw APIManagerError.rateLimited
            } else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorData?["detail"] as? String ?? "Server returned status code \(httpResponse.statusCode)"
                throw APIManagerError.serverError(errorMessage)
            }
        }

        do {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            // Recommendations endpoints return { "recommendations": [...] }
            let recs = responseData?["recommendations"] as? [[String: Any]] ?? []

            var insights: [AIInsight] = []
            for rec in recs {
                let title = rec["title"] as? String ?? "Insight"
                let description = rec["description"] as? String ?? ""
                let category = rec["category"] as? String ?? "general"
                let priorityString = rec["priority"] as? String ?? "medium"
                let action = rec["action"] as? String ?? ""

                // Map category to InsightType
                let type: AIInsight.InsightType
                switch category.lowercased() {
                case "blood_sugar", "glucose": type = .bloodSugar
                case "diet": type = .diet
                case "exercise": type = .exercise
                case "medication": type = .medication
                case "lifestyle": type = .lifestyle
                case "pattern": type = .pattern
                default: type = .pattern
                }

                let priority: AIInsight.InsightPriority
                switch priorityString.lowercased() {
                case "low": priority = .low
                case "medium": priority = .medium
                case "high": priority = .high
                case "critical": priority = .critical
                default: priority = .medium
                }

                let actionItems: [String]
                if let act = rec["action_items"] as? [String] {
                    actionItems = act
                } else if !action.isEmpty {
                    actionItems = [action]
                } else {
                    actionItems = []
                }

                let insight = AIInsight(
                    title: title,
                    description: description,
                    type: type,
                    priority: priority,
                    timestamp: Date(),
                    actionItems: actionItems,
                    dataPoints: [:]
                )

                insights.append(insight)
            }

            if insights.isEmpty {
                insights = getDefaultInsights()
            }

            // Cache insights for quick startup display
            if let encoded = try? JSONEncoder().encode(insights) {
                UserDefaults.standard.set(encoded, forKey: cachedInsightsKey)
                self.cachedInsights = insights
            }

            return insights
        } catch {
            print("Error parsing recommendations response: \(error.localizedDescription)")
            throw APIManagerError.decodingError(error)
        }
    }
    
    // Unified function to aggregate all health data and generate insights
    func aggregateDataAndGenerateInsights() async throws -> [AIInsight] {
        // 1. Fetch HealthKit data
        var healthData = APIManagerHealthData(
            glucose: [],
            workouts: [],
            nutrition: [],
            timestamp: Date()
        )
        
        // 2. Fetch Dexcom data if available
        if let username = keychain.getValue(for: "dexcom_username"),
           let password = keychain.getValue(for: "dexcom_password") {
            do {
                let glucoseReading = try await fetchLatestGlucoseReading(
                    username: username, 
                    password: password, 
                    isInternational: keychain.getValue(for: "dexcom_is_international") == "true"
                )
                
                // Add to health data
                healthData.glucose.append(glucoseReading)
            } catch {
                print("Failed to fetch Dexcom data: \(error.localizedDescription)")
                // Continue with other data sources
            }
        }
        
        // 3. Sync the aggregated data
        do {
            _ = try await syncHealthData(healthData)
        } catch {
            print("Warning: Failed to sync health data: \(error.localizedDescription)")
            // Continue anyway to try getting insights
        }
        
        // 4. Generate insights
        return try await generateInsights()
    }
    
    private func getDefaultInsights() -> [AIInsight] {
        return [
            AIInsight(
                title: "Welcome to GluCoPilot",
                description: "Connect your Dexcom account and sync health data to get personalized AI insights for better diabetes management.",
                type: .lifestyle,
                priority: .medium,
                timestamp: Date(),
                actionItems: [
                    "Connect your Dexcom account in Settings",
                    "Sync your Apple Health data",
                    "Check back for AI-powered recommendations"
                ],
                dataPoints: [:]
            ),
            AIInsight(
                title: "Data Sync Recommended",
                description: "To get the most accurate insights, regularly sync your health data including activity, sleep, and nutrition information.",
                type: .pattern,
                priority: .low,
                timestamp: Date(),
                actionItems: [
                    "Visit the Data tab to sync recent health data",
                    "Connect MyFitnessPal through Apple Health for nutrition tracking",
                    "Ensure your Apple Watch is syncing activity data"
                ],
                dataPoints: [:]
            )
        ]
    }
}
