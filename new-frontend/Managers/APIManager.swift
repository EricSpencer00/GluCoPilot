import Foundation

@MainActor
class APIManager: ObservableObject {
    private let baseURL = "https://glucopilot-8ed6389c53c8.herokuapp.com"
    private let session = URLSession.shared
    private let keychain = KeychainHelper()
    
    // MARK: - Authentication
    func validateDexcomCredentials(username: String, password: String, isInternational: Bool) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/dexcom/signin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple ID token for authentication
        if let appleUserID = keychain.getValue(for: "apple_user_id") {
            request.setValue("Bearer \(appleUserID)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "username": username,
            "password": password,
            "ous": isInternational
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["detail"] as? String ?? "Invalid credentials"
            throw APIError.serverError(errorMessage)
        }
    }
    
    func fetchLatestGlucoseReading(username: String, password: String, isInternational: Bool) async throws -> GlucoseReading {
        let url = URL(string: "\(baseURL)/api/v1/glucose/stateless/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple ID token for authentication
        if let appleUserID = keychain.getValue(for: "apple_user_id") {
            request.setValue("Bearer \(appleUserID)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "username": username,
            "password": password,
            "ous": isInternational
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch glucose reading")
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let readings = responseData?["readings"] as? [[String: Any]]
        
        guard let firstReading = readings?.first,
              let value = firstReading["value"] as? Int,
              let trend = firstReading["trend"] as? String,
              let timestampString = firstReading["timestamp"] as? String else {
            throw APIError.invalidData
        }
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: timestampString) ?? Date()
        
        return GlucoseReading(
            value: value,
            trend: trend,
            timestamp: timestamp,
            unit: "mg/dL"
        )
    }
    
    // MARK: - Health Data Sync
    func syncHealthData(_ healthData: HealthData) async throws -> SyncResults {
        let url = URL(string: "\(baseURL)/api/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple ID token for authentication
        if let appleUserID = keychain.getValue(for: "apple_user_id") {
            request.setValue("Bearer \(appleUserID)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(healthData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to sync health data")
        }
        
        // Parse sync results
        return SyncResults(
            recordCount: healthData.workouts.count + (healthData.steps > 0 ? 1 : 0) + (healthData.sleepHours > 0 ? 1 : 0),
            stepCount: healthData.steps,
            workoutCount: healthData.workouts.count,
            sleepHours: healthData.sleepHours
        )
    }
    
    // MARK: - AI Insights
    func generateInsights() async throws -> [AIInsight] {
        let url = URL(string: "\(baseURL)/api/insights/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Apple ID token for authentication
        if let appleUserID = keychain.getValue(for: "apple_user_id") {
            request.setValue("Bearer \(appleUserID)", forHTTPHeaderField: "Authorization")
        }
        
        // Request insights for the last 24 hours
        let body = [
            "timeframe": "24h",
            "include_recommendations": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to generate insights")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Parse the response
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let insightsArray = responseData?["insights"] as? [[String: Any]] ?? []
        
        // Convert to AIInsight objects
        var insights: [AIInsight] = []
        
        for insightData in insightsArray {
            guard let title = insightData["title"] as? String,
                  let description = insightData["description"] as? String,
                  let category = insightData["category"] as? String,
                  let priorityString = insightData["priority"] as? String,
                  let priority = AIInsight.Priority(rawValue: priorityString.capitalized) else {
                continue
            }
            
            let actionItems = insightData["action_items"] as? [String] ?? []
            
            let insight = AIInsight(
                title: title,
                description: description,
                category: category,
                priority: priority,
                actionItems: actionItems,
                timestamp: Date()
            )
            
            insights.append(insight)
        }
        
        // If no insights from API, provide some default ones
        if insights.isEmpty {
            insights = getDefaultInsights()
        }
        
        return insights
    }
    
    private func getDefaultInsights() -> [AIInsight] {
        return [
            AIInsight(
                title: "Welcome to GluCoPilot",
                description: "Connect your Dexcom account and sync health data to get personalized AI insights for better diabetes management.",
                category: "General",
                priority: .medium,
                actionItems: [
                    "Connect your Dexcom account in Settings",
                    "Sync your Apple Health data",
                    "Check back for AI-powered recommendations"
                ],
                timestamp: Date()
            ),
            AIInsight(
                title: "Data Sync Recommended",
                description: "To get the most accurate insights, regularly sync your health data including activity, sleep, and nutrition information.",
                category: "General",
                priority: .low,
                actionItems: [
                    "Visit the Data tab to sync recent health data",
                    "Connect MyFitnessPal through Apple Health for nutrition tracking",
                    "Ensure your Apple Watch is syncing activity data"
                ],
                timestamp: Date()
            )
        ]
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidResponse
    case invalidData
    case serverError(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidData:
            return "Invalid data received from server"
        case .serverError(let message):
            return message
        case .networkError:
            return "Network connection error"
        }
    }
}
