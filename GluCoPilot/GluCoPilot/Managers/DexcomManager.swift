import Foundation

@MainActor
class DexcomManager: ObservableObject {
    @Published var isConnected = false
    @Published var latestGlucoseReading: GlucoseReading?
    @Published var isLoading = false
    
    private let keychain = KeychainHelper()
    private let apiManager = APIManager()
    
    init() {
        checkConnectionStatus()
    }
    
    func checkConnectionStatus() {
        // Check if we have stored Dexcom credentials
        if keychain.getValue(for: "dexcom_username") != nil,
           keychain.getValue(for: "dexcom_password") != nil {
            isConnected = true
        }
    }
    
    func connect(username: String, password: String, isInternational: Bool) async throws {
        isLoading = true
        
        do {
            // Validate credentials with backend
            let success = try await apiManager.validateDexcomCredentials(
                username: username,
                password: password,
                isInternational: isInternational
            )
            
            if success {
                // Store credentials securely
                keychain.setValue(username, for: "dexcom_username")
                keychain.setValue(password, for: "dexcom_password")
                keychain.setValue(String(isInternational), for: "dexcom_is_international")
                
                isConnected = true
                
                // Fetch initial glucose reading
                try await fetchLatestGlucoseReading()
            } else {
                throw DexcomError.invalidCredentials
            }
        } catch {
            isConnected = false
            throw error
        } finally {
            isLoading = false
        }
    }
    
    func disconnect() {
        // Clear stored credentials
        keychain.deleteValue(for: "dexcom_username")
        keychain.deleteValue(for: "dexcom_password")
        keychain.deleteValue(for: "dexcom_is_international")
        
        isConnected = false
        latestGlucoseReading = nil
    }
    
    func fetchLatestGlucoseReading() async throws {
        guard isConnected,
              let username = keychain.getValue(for: "dexcom_username"),
              let password = keychain.getValue(for: "dexcom_password"),
              let internationalStr = keychain.getValue(for: "dexcom_is_international") else {
            throw DexcomError.notConnected
        }
        
        let isInternational = Bool(internationalStr) ?? false
        
        do {
            let reading = try await apiManager.fetchLatestGlucoseReading(
                username: username,
                password: password,
                isInternational: isInternational
            )
            latestGlucoseReading = reading
        } catch {
            print("Error fetching glucose reading: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Data Models
struct GlucoseReading: Codable, Identifiable {
    let id = UUID()
    let value: Int
    let trend: String
    let timestamp: Date
    let unit: String
    
    var trendArrow: String {
        switch trend.lowercased() {
        case "rising rapidly", "doubleup": return "⇈"
        case "rising", "singleup": return "↗"
        case "rising slightly", "fortyfiveup": return "→"
        case "stable", "flat": return "→"
        case "falling slightly", "fortyfivedown": return "↘"
        case "falling", "singledown": return "↓"
        case "falling rapidly", "doubledown": return "⇊"
        default: return "?"
        }
    }
    
    var isInRange: Bool {
        return value >= 80 && value <= 180
    }
    
    var color: String {
        if value < 70 { return "red" }
        else if value < 80 { return "orange" }
        else if value <= 180 { return "green" }
        else if value <= 250 { return "orange" }
        else { return "red" }
    }
}

// MARK: - Errors
enum DexcomError: LocalizedError {
    case notConnected
    case invalidCredentials
    case networkError
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Dexcom is not connected"
        case .invalidCredentials:
            return "Invalid Dexcom credentials"
        case .networkError:
            return "Network connection error"
        case .serverError:
            return "Server error occurred"
        }
    }
}
