import Foundation

// MARK: - API Manager Models (Isolated to avoid conflicts)
struct APIManagerGlucoseReading: Codable, Identifiable {
    var id = UUID()
    let value: Int
    let trend: String
    let timestamp: Date
    let unit: String
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

// MARK: - Recommendation model (minimal)
struct SimpleRecommendation: Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let category: String
    let priority: String
    let confidence: Double
    let action: String
    let timing: String?
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
    private let baseURL = "https://glucopilot-8ed6389c53c8.herokuapp.com"
    private let session = URLSession.shared
    private let keychain = APIManagerKeychainHelper()
    
    // Clear any stored auth tokens
    func clearTokens() {
        keychain.removeValue(for: "auth_access_token")
        keychain.removeValue(for: "auth_refresh_token")
        keychain.removeValue(for: "apple_id_token")
        keychain.removeValue(for: "apple_user_id")
    }
    
    // Helper to prefer backend-issued access token over raw Apple id_token
    private func getAuthToken() -> String? {
        // Prefer stored backend access token
        if let appToken = keychain.getValue(for: "auth_access_token") {
            return appToken
        }
        // Fallback to Apple id_token if no app token available
        return keychain.getValue(for: "apple_id_token")
    }
    
    // MARK: - JWT helpers
    private func base64UrlDecode(_ str: String) -> Data? {
        var s = str
        s = s.replacingOccurrences(of: "-", with: "+")
        s = s.replacingOccurrences(of: "_", with: "/")
        let pad = 4 - (s.count % 4)
        if pad < 4 { s += String(repeating: "=", count: pad) }
        return Data(base64Encoded: s)
    }
    
    private func parseJWTClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = base64UrlDecode(payload) else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        return nil
    }
    
    private func tokenIsExpired(_ token: String, leeway: TimeInterval = 60) -> Bool {
        guard let claims = parseJWTClaims(token) else { return false }
        if let exp = claims["exp"] as? TimeInterval {
            let expDate = Date(timeIntervalSince1970: exp)
            return Date() > expDate.addingTimeInterval(-leeway)
        }
        return false
    }
    
    // Try to detect Apple id_token by decoding JWT header and checking alg==RS256
    private func isAppleIdToken(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let headerB64 = String(parts[0])
        var base64 = headerB64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else { return false }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let alg = obj["alg"] as? String
        return alg == "RS256"
    }
    
    // Ensure we have a backend-issued access token (HS256). If only an Apple id_token is present,
    // call /api/v1/auth/social-login to exchange it for a backend token and persist it.
    private func ensureBackendToken() async throws -> String {
        // If we already have backend token, return it
        if let appToken = keychain.getValue(for: "auth_access_token") {
            // If token appears expired, try to exchange via Apple id_token
            if tokenIsExpired(appToken) {
                // Attempt to exchange using Apple id_token (may refresh tokens)
                if let new = await exchangeAppleIdTokenForBackendToken() {
                    return new
                }
                // If unable to refresh, remove stale token and fallthrough
                keychain.removeValue(for: "auth_access_token")
                keychain.removeValue(for: "auth_refresh_token")
            } else {
                return appToken
            }
        }
        
        // If we have an Apple id_token, attempt exchange
        if let appleToken = keychain.getValue(for: "apple_id_token"), isAppleIdToken(appleToken) {
            // Build request to social-login endpoint to exchange id_token for app token
            let url = URL(string: "\(baseURL)/api/v1/auth/social-login")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Include Apple id_token in Authorization header as backend expects
            request.setValue("Bearer \(appleToken)", forHTTPHeaderField: "Authorization")
            
            let body: [String: Any] = [
                "provider": "apple",
                "id_token": appleToken
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIManagerError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                // If exchange failed, propagate unauthorized
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw APIManagerError.unauthorized
                }
                let err = String(data: data, encoding: .utf8) ?? ""
                throw APIManagerError.serverError(err)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let access = json["access_token"] as? String {
                keychain.setValue(access, for: "auth_access_token")
                if let refresh = json["refresh_token"] as? String {
                    keychain.setValue(refresh, for: "auth_refresh_token")
                }
                return access
            }
            
            throw APIManagerError.invalidData
        }
        
        // No token available
        throw APIManagerError.unauthorized
    }
    
    // MARK: - Authentication
    func validateDexcomCredentials(username: String, password: String, isInternational: Bool) async throws -> Bool {
        // Dexcom integration removed. This API previously validated Dexcom Share
        // credentials against the backend. Dexcom is deprecated — prefer HealthKit.
        print("[APIManager] validateDexcomCredentials called but Dexcom integration is removed")
        return false
    }
    
    // Register a user with Apple ID
    func registerWithAppleID(userID: String, fullName: String?, email: String?) async throws -> Bool {
        // Require Apple id_token (JWT) to register with backend
        guard let authToken = getAuthToken() else {
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
        
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Store the user ID in keychain
            keychain.setValue(userID, for: "apple_user_id")
            // If backend returned app tokens in the response body, persist them for future calls
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let access = json["access_token"] as? String {
                    keychain.setValue(access, for: "auth_access_token")
                }
                if let refresh = json["refresh_token"] as? String {
                    keychain.setValue(refresh, for: "auth_refresh_token")
                }
            }
            return true
        } else if httpResponse.statusCode == 404 {
            // Backend returned Not Found - this can happen if server doesn't support auto-registration.
            // Treat it as non-fatal: log and return false so UI can continue working locally.
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[APIManager] registerWithAppleID -> 404 Not Found: \(bodyStr)")
            return false
        } else {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["detail"] as? String ?? "Registration failed"
            throw APIManagerError.serverError(errorMessage)
        }
    }
    
    func fetchLatestGlucoseReading(username: String, password: String, isInternational: Bool) async throws -> APIManagerGlucoseReading {
        // Dexcom stateless sync removed. Fetch glucose from HealthKit on the client
        // and send to backend via syncHealthData(_:).
        throw APIManagerError.invalidResponse
    }
    
    // MARK: - Health Data Sync
    func syncHealthData(_ healthData: APIManagerHealthData) async throws -> APIManagerSyncResults {
        // Try to obtain a backend-issued access token; attempt exchange if missing.
        var authToken: String? = try? await ensureBackendToken()
        if authToken == nil {
            authToken = await exchangeAppleIdTokenForBackendToken()
        }
        
        // If we still don't have a token, return a graceful result with an authentication error
        if authToken == nil {
            return APIManagerSyncResults(
                glucoseReadings: healthData.glucose.count,
                workouts: healthData.workouts?.count ?? 0,
                nutritionEntries: healthData.nutrition?.count ?? 0,
                errors: ["Authentication required"],
                lastSyncDate: Date()
            )
        }
        
        let url = URL(string: "\(baseURL)/api/v1/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Authorization header with preferred token
        request.setValue("Bearer \(authToken!)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Backend expects a body like: { "data": { ...health data... }, "platform": "apple_health" }
        let healthDataEncoded = try encoder.encode(healthData)
        let healthJson = (try? JSONSerialization.jsonObject(with: healthDataEncoded)) as? [String: Any] ?? [:]
        let wrapper: [String: Any] = [
            "platform": "apple_health",
            "data": healthJson
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: wrapper)
        
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
    
    // MARK: - Dev helper: fetch test recommendations using stateless backend bypass
    func fetchTestRecommendations() async throws -> [SimpleRecommendation] {
        // Ensure we have a backend-issued access token for protected endpoints
        let authToken = try await ensureBackendToken()
        
        let url = URL(string: "\(baseURL)/api/v1/recommendations/stateless")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["username": "__test__", "password": "x", "ous": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIManagerError.unauthorized
            } else {
                let err = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIManagerError.serverError(err)
            }
        }
        
        // Parse recommendations list
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let recs = decoded?["recommendations"] as? [[String: Any]] ?? []
        var results: [SimpleRecommendation] = []
        for r in recs {
            let rec = SimpleRecommendation(
                title: r["title"] as? String ?? "",
                description: r["description"] as? String ?? "",
                category: r["category"] as? String ?? "general",
                priority: r["priority"] as? String ?? "medium",
                confidence: r["confidence"] as? Double ?? (r["confidence"] as? NSNumber)?.doubleValue ?? 0.7,
                action: r["action"] as? String ?? "",
                timing: r["timing"] as? String
            )
            results.append(rec)
        }
        
        return results
    }
    
    // MARK: - Debug helper: send raw Apple id_token to backend debug endpoint
    /// Sends a raw Apple id_token to the backend debug endpoint and returns the issued access token.
    /// This method is compiled only in DEBUG builds to avoid shipping debug helpers to production.
#if DEBUG
    func debugSendAppleIdToken(_ idToken: String, email: String? = nil, firstName: String? = nil, lastName: String? = nil) async throws -> (accessToken: String, refreshToken: String?) {
        let url = URL(string: "\(baseURL)/api/v1/auth/debug/social-login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken
        ]
        if let email = email { body["email"] = email }
        if let firstName = firstName { body["first_name"] = firstName }
        if let lastName = lastName { body["last_name"] = lastName }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIManagerError.invalidResponse }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 { throw APIManagerError.unauthorized }
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            throw APIManagerError.serverError(bodyStr)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let access = json["access_token"] as? String else {
            throw APIManagerError.invalidData
        }
        
        // Persist tokens in keychain for convenience during dev testing
        keychain.setValue(access, for: "auth_access_token")
        if let refresh = json["refresh_token"] as? String {
            keychain.setValue(refresh, for: "auth_refresh_token")
        }
        
        return (accessToken: access, refreshToken: json["refresh_token"] as? String)
    }
#endif
    
#if DEBUG
    /// Debug wrapper that exposes ensureBackendToken for debug UIs/tests.
    func debugEnsureBackendToken() async throws -> String {
        return try await ensureBackendToken()
    }
    
    /// Debug handler for token issues - provides better visibility for token problems and
    /// attempts multiple refresh strategies. Used by the AppleSignInDebugView for safe token debugging.
    func debugEnsureBackendToken(completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                // Step 1: Try to use existing backend token if valid
                if let appToken = keychain.getValue(for: "auth_access_token") {
                    if !tokenIsExpired(appToken) {
                        // Token exists and is valid
                        completion(.success("Using existing valid backend token"))
                        return
                    } else {
                        // Token exists but is expired
                        print("[Debug] Backend access token is expired, attempting refresh")
                    }
                } else {
                    print("[Debug] No backend access token found, attempting Apple token exchange")
                }
                
                // Step 2: Check if we have a refresh token, and if it's valid
                if let refreshToken = keychain.getValue(for: "auth_refresh_token"), !tokenIsExpired(refreshToken) {
                    print("[Debug] Found valid refresh token, but backend doesn't support /auth/refresh endpoint")
                    // Note: Backend doesn't have a dedicated refresh endpoint yet
                    // This would be the place to implement refresh token usage
                }
                
                // Step 3: Check if we have an Apple ID token and try exchange
                if let appleToken = keychain.getValue(for: "apple_id_token") {
                    if isAppleIdToken(appleToken) {
                        // Apple token exists and has the right format
                        // Attempt to exchange it for a backend token
                        if let newToken = await exchangeAppleIdTokenForBackendToken() {
                            completion(.success("Successfully exchanged Apple ID token for new backend token"))
                            return
                        } else {
                            print("[Debug] Failed to exchange Apple ID token")
                        }
                    } else {
                        print("[Debug] Found Apple ID token but it appears invalid (not RS256)")
                    }
                } else {
                    print("[Debug] No Apple ID token found")
                }
                
                // Final step: Try to use full ensureBackendToken to attempt all strategies
                let finalToken = try await ensureBackendToken()
                completion(.success("Successfully obtained backend token via ensureBackendToken"))
            } catch {
                completion(.failure(error))
                }
            }
        }
    #endif
    
    // MARK: - AI Insights
    /// Fetch AI insights for a specific day. This is the primary method used by AIInsightsView.
    /// Includes robust token handling, fallbacks, and error recovery.
    func fetchAIInsights(forDay date: Date) async throws -> [AIInsight] {
        print("[APIManager] fetchAIInsights called for date: \(date)")
        
        // Strategy 1: Try with existing backend token
        var authToken: String? = keychain.getValue(for: "auth_access_token")
        if let token = authToken, !tokenIsExpired(token) {
            do {
                return try await fetchInsightsWithToken(token, forDay: date)
            } catch APIManagerError.unauthorized {
                // Token was rejected, continue to next strategy
                print("[APIManager] Backend token was rejected, trying refresh")
            } catch {
                // For other errors, rethrow
                throw error
            }
        }
        
        // Strategy 2: Try to exchange Apple id_token for a new backend token
        if let appleToken = keychain.getValue(for: "apple_id_token"), isAppleIdToken(appleToken) {
            if let newToken = await exchangeAppleIdTokenForBackendToken() {
                do {
                    return try await fetchInsightsWithToken(newToken, forDay: date)
                } catch {
                    // Log but continue to next strategy
                    print("[APIManager] Refreshed token still failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Strategy 3: Try ensureBackendToken which attempts all available strategies
        do {
            let token = try await ensureBackendToken()
            return try await fetchInsightsWithToken(token, forDay: date)
        } catch APIManagerError.unauthorized {
            // All auth strategies failed, try stateless mode as last resort
            print("[APIManager] All token strategies failed, trying stateless mode")
        } catch {
            throw error
        }
        
        // Strategy 4: Last resort - stateless mode
        // This only works in development/staging environments where API key auth is disabled
        return try await fetchInsightsStateless(forDay: date)
    }    // Helper method to fetch insights with a specific token
    private func fetchInsightsWithToken(_ token: String, forDay date: Date) async throws -> [AIInsight] {
        let url = URL(string: "\(baseURL)/api/v1/detailed-insights/day")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Format date as YYYY-MM-DD for the API
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // Add date parameter to URL
        let urlWithDate = URL(string: "\(url.absoluteString)?date=\(dateString)")!
        request.url = urlWithDate
        
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
        
        return try parseInsightsResponse(data: data)
    }
    
    // Stateless mode - used as last resort when authentication fails
    private func fetchInsightsStateless(forDay date: Date) async throws -> [AIInsight] {
        let url = URL(string: "\(baseURL)/api/v1/insights/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Format date as YYYY-MM-DD for the API
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // Minimal payload for stateless generation
        let body: [String: Any] = [
            "timeframe": "24h",
            "include_recommendations": true,
            "date": dateString,
            "health_data": [
                "glucose": [],
                "activity": [],
                "food": []
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIManagerError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorData?["detail"] as? String ?? "Server returned status code \(httpResponse.statusCode)"
            throw APIManagerError.serverError(errorMessage)
        }
        
        return try parseInsightsResponse(data: data)
    }
    /// Generate insights, allowing callers to pass local health data (stateless) and an optional user prompt.
    /// If auth is available, it will be attached; otherwise the backend should accept stateless payloads in non-prod.
    func generateInsights(healthData: APIManagerHealthData?, prompt: String? = nil) async throws -> [AIInsight] {
        // Prefer a backend-issued token but allow stateless calls
        let authToken = try? await ensureBackendToken()
        
        let url = URL(string: "\(baseURL)/api/v1/insights/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var payload: [String: Any] = ["timeframe": "24h", "include_recommendations": true]
        if let prompt = prompt { payload["prompt"] = prompt }
        if let healthData = healthData {
            // Build backend-expected structure
            let glucose = healthData.glucose.map { g in
                return [
                    "value": g.value,
                    "trend": g.trend,
                    "timestamp": ISO8601DateFormatter().string(from: g.timestamp),
                    "unit": g.unit
                ] as [String: Any]
            }
            let activity = (healthData.workouts ?? []).map { w in
                return [
                    "type": w.type,
                    "duration": w.duration,
                    "calories": w.calories as Any,
                    "start": ISO8601DateFormatter().string(from: w.startDate),
                    "end": ISO8601DateFormatter().string(from: w.endDate)
                ] as [String: Any]
            }
            let food = (healthData.nutrition ?? []).map { n in
                return [
                    "name": n.name,
                    "calories": n.calories,
                    "carbs": n.carbs,
                    "protein": n.protein,
                    "fat": n.fat,
                    "timestamp": ISO8601DateFormatter().string(from: n.timestamp)
                ] as [String: Any]
            }
            payload["health_data"] = [
                "glucose": glucose,
                "activity": activity,
                "food": food
            ]
        } else {
            payload["health_data"] = [
                "glucose": [],
                "activity": [],
                "food": []
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIManagerError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Try exchange once and retry
                if let newToken = await exchangeAppleIdTokenForBackendToken() {
                    var retry = URLRequest(url: url)
                    retry.httpMethod = "POST"
                    retry.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    retry.httpBody = request.httpBody
                    let (rd, rr) = try await session.data(for: retry)
                    if let http = rr as? HTTPURLResponse, http.statusCode == 200 {
                        return try parseInsightsResponse(data: rd)
                    }
                }
                throw APIManagerError.unauthorized
            }
            let err = String(data: data, encoding: .utf8) ?? "<no body>"
            throw APIManagerError.serverError(err)
        }
        
        return try parseInsightsResponse(data: data)
    }
    
    // Simplified version for backward compatibility
    func generateInsights() async throws -> [AIInsight] {
        return try await generateInsights(healthData: nil, prompt: nil)
    }
    
    private func parseInsightsResponse(data: Data) throws -> [AIInsight] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let insightsArray = responseData?["insights"] as? [[String: Any]] ?? []
            
            var insights: [AIInsight] = []
            for insightData in insightsArray {
                let title = insightData["title"] as? String ?? "Insight"
                let desc = (insightData["content"] as? String) ?? (insightData["description"] as? String) ?? ""
                let typeString = (insightData["type"] as? String) ?? (insightData["category"] as? String) ?? "pattern"
                let priorityString = (insightData["priority"] as? String) ?? "medium"
                
                let actionList = (insightData["action_items"] as? [String]) ?? []
                let dataPoints = insightData["data_points"] as? [String: Double] ?? [:]
                
                let type: AIInsight.InsightType
                switch typeString {
                case "blood_sugar": type = .bloodSugar
                case "diet": type = .diet
                case "exercise": type = .exercise
                case "medication": type = .medication
                case "lifestyle": type = .lifestyle
                case "pattern": type = .pattern
                default: type = .pattern
                }
                
                let priority: AIInsight.InsightPriority
                switch priorityString {
                case "low": priority = .low
                case "medium": priority = .medium
                case "high": priority = .high
                case "critical": priority = .critical
                default: priority = .medium
                }
                
                let insight = AIInsight(
                    title: title,
                    description: desc,
                    type: type,
                    priority: priority,
                    timestamp: Date(),
                    actionItems: actionList,
                    dataPoints: dataPoints
                )
                insights.append(insight)
            }
            
            if insights.isEmpty { insights = getDefaultInsights() }
            return insights
        } catch {
            print("Error parsing insights response: \(error.localizedDescription)")
            throw APIManagerError.decodingError(error)
        }
    }
    // Attempt to exchange a stored Apple id_token for a backend-issued access token.
    // Returns the new access token or nil on failure.
    private func exchangeAppleIdTokenForBackendToken() async -> String? {
        guard let appleToken = keychain.getValue(for: "apple_id_token") else { return nil }
        let url = URL(string: "\(baseURL)/api/v1/auth/social-login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["provider": "apple", "id_token": appleToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let access = json["access_token"] as? String {
                keychain.setValue(access, for: "auth_access_token")
                if let refresh = json["refresh_token"] as? String { keychain.setValue(refresh, for: "auth_refresh_token") }
                return access
            }
        } catch {
            print("Failed to exchange Apple id_token for backend token: \(error.localizedDescription)")
        }
        return nil
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
        
        // 2. Dexcom integration removed. HealthKit is the preferred source for glucose data.
        
        // 3. Sync the aggregated data. If sync fails due to auth, continue — insights will still be attempted in stateless mode.
        do {
            let syncResult = try await syncHealthData(healthData)
            if !syncResult.errors.isEmpty {
                print("Info: syncHealthData returned errors: \(syncResult.errors)")
            }
        } catch {
            print("Info: syncHealthData failed; continuing to generate insights: \(error.localizedDescription)")
        }
        
        // 4. Generate insights
        return try await generateInsights()
    }
    
    // Upload local cache (logs) plus HealthKit context (24h) and ask backend to generate insights
    func uploadCacheAndGenerateInsights(healthData: APIManagerHealthData, cachedItems: [CacheManager.LoggedItem]) async throws -> [AIInsight] {
        // Try to obtain a backend-issued token, but allow unauthenticated/stateless calls
        // (backend in non-production accepts missing api_key / bearer token for /generate)
        let authToken = try? await ensureBackendToken()
        print("[APIManager] uploadCacheAndGenerateInsights called. authTokenPresent=\(authToken != nil)")
        
        // Use the backend "generate" endpoint which supports stateless mode (health_data in body)
        let url = URL(string: "\(baseURL)/api/v1/insights/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("[APIManager] No backend token available; calling generate endpoint in stateless mode")
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Build payload
        var payload: [String: Any] = [:]
        let healthDataEncoded = try encoder.encode(healthData)
        let healthJson = (try? JSONSerialization.jsonObject(with: healthDataEncoded)) as? [String: Any] ?? [:]
        payload["health_data"] = healthJson
        
        // Convert cached items
        let cached: [[String: Any]] = cachedItems.map { item in
            return [
                "id": item.id.uuidString,
                "type": item.type,
                "payload": item.payload,
                "timestamp": ISO8601DateFormatter().string(from: item.timestamp)
            ]
        }
        payload["cached_items"] = cached
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("[APIManager] /insights/generate responded: \(httpResponse.statusCode)")
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw APIManagerError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Try exchanging Apple id_token for app token and retry once
                if let newToken = await exchangeAppleIdTokenForBackendToken() {
                    var retryRequest = URLRequest(url: url)
                    retryRequest.httpMethod = "POST"
                    retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    retryRequest.httpBody = request.httpBody
                    let (retryData, retryResponse) = try await session.data(for: retryRequest)
                    if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 {
                        let responseData = try JSONSerialization.jsonObject(with: retryData) as? [String: Any]
                        let insightsArray = responseData?["insights"] as? [[String: Any]] ?? []
                        var insights: [AIInsight] = []
                        for insightData in insightsArray {
                            guard let title = insightData["title"] as? String,
                                  let description = insightData["description"] as? String,
                                  let typeString = insightData["type"] as? String,
                                  let priorityString = insightData["priority"] as? String else { continue }
                            
                            let actionItems = insightData["action_items"] as? [String] ?? []
                            let dataPoints = insightData["data_points"] as? [String: Double] ?? [:]
                            
                            let type: AIInsight.InsightType
                            switch typeString {
                            case "blood_sugar": type = .bloodSugar
                            case "diet": type = .diet
                            case "exercise": type = .exercise
                            case "medication": type = .medication
                            case "lifestyle": type = .lifestyle
                            case "pattern": type = .pattern
                            default: type = .pattern
                            }
                            
                            let priority: AIInsight.InsightPriority
                            switch priorityString {
                            case "low": priority = .low
                            case "medium": priority = .medium
                            case "high": priority = .high
                            case "critical": priority = .critical
                            default: priority = .medium
                            }
                            
                            let insight = AIInsight(
                                title: title,
                                description: description,
                                type: type,
                                priority: priority,
                                timestamp: Date(),
                                actionItems: actionItems,
                                dataPoints: dataPoints
                            )
                            insights.append(insight)
                        }
                        
                        if insights.isEmpty { insights = getDefaultInsights() }
                        return insights
                    }
                }
                throw APIManagerError.unauthorized
            }
            let err = String(data: data, encoding: .utf8) ?? "<no body>"
            throw APIManagerError.serverError(err)
        }
        
        // Reuse generateInsights parsing logic by decoding the API response
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let insightsArray = responseData?["insights"] as? [[String: Any]] ?? []
        
        var insights: [AIInsight] = []
        for insightData in insightsArray {
            guard let title = insightData["title"] as? String,
                  let description = insightData["description"] as? String,
                  let typeString = insightData["type"] as? String,
                  let priorityString = insightData["priority"] as? String else { continue }
            
            let actionItems = insightData["action_items"] as? [String] ?? []
            let dataPoints = insightData["data_points"] as? [String: Double] ?? [:]
            
            let type: AIInsight.InsightType
            switch typeString {
            case "blood_sugar": type = .bloodSugar
            case "diet": type = .diet
            case "exercise": type = .exercise
            case "medication": type = .medication
            case "lifestyle": type = .lifestyle
            case "pattern": type = .pattern
            default: type = .pattern
            }
            
            let priority: AIInsight.InsightPriority
            switch priorityString {
            case "low": priority = .low
            case "medium": priority = .medium
            case "high": priority = .high
            case "critical": priority = .critical
            default: priority = .medium
            }
            
            let insight = AIInsight(
                title: title,
                description: description,
                type: type,
                priority: priority,
                timestamp: Date(),
                actionItems: actionItems,
                dataPoints: dataPoints
            )
            insights.append(insight)
        }
        
        if insights.isEmpty { insights = getDefaultInsights() }
        return insights
    }
    
    private func getDefaultInsights() -> [AIInsight] {
        return [
            AIInsight(
                title: "Welcome to GluCoPilot",
                description: "Sync your Apple Health data to get personalized AI insights for better diabetes management.",
                type: .lifestyle,
                priority: .medium,
                timestamp: Date(),
                actionItems: [
                    "Sync your Apple Health data",
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
