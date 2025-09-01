import Foundation
import SwiftUI

// MARK: - Helper Classes (Inline to avoid import issues)
class KeychainHelper {
    func setValue(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Error storing keychain item: \(status)")
        }
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
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    func deleteValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Models
struct GlucoseReading: Codable, Identifiable {
    var id: UUID { UUID() }
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

// MARK: - Error Models
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

@MainActor
class DexcomManager: ObservableObject {
    @Published var isConnected = false
    @Published var latestGlucoseReading: GlucoseReading?
    @Published var isLoading = false
    
    private let keychain = KeychainHelper()
    // Note: Will use environment object for APIManager to avoid circular dependency
    
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
    
    func connect(username: String, password: String, isInternational: Bool, apiManager: Any) async throws {
        isLoading = true
        defer {
            isLoading = false
        }
        
        // For now, we'll handle the connection without API validation
        // This can be updated once the module structure is properly resolved
        
        // Store credentials securely (assuming they're valid for now)
        keychain.setValue(username, for: "dexcom_username")
        keychain.setValue(password, for: "dexcom_password")
        keychain.setValue(String(isInternational), for: "dexcom_is_international")
        
        isConnected = true
        
        // Note: Actual API validation will be added once module structure is resolved
        print("Dexcom credentials stored. API validation will be implemented.")
    }
    
    func disconnect() {
        // Clear stored credentials
        keychain.deleteValue(for: "dexcom_username")
        keychain.deleteValue(for: "dexcom_password")
        keychain.deleteValue(for: "dexcom_is_international")
        
        isConnected = false
        latestGlucoseReading = nil
    }
    
    func fetchLatestGlucoseReading(apiManager: Any? = nil) async throws {
        guard isConnected,
              let _ = keychain.getValue(for: "dexcom_username"),
              let _ = keychain.getValue(for: "dexcom_password"),
              let _ = keychain.getValue(for: "dexcom_is_international") else {
            throw DexcomError.notConnected
        }
        
        // For now, create a mock glucose reading
        // This will be replaced with actual API call once module structure is resolved
        let mockReading = GlucoseReading(
            value: Int.random(in: 80...200),
            trend: "flat",
            timestamp: Date(),
            unit: "mg/dL"
        )
        
        await MainActor.run {
            latestGlucoseReading = mockReading
        }
        
        print("Mock glucose reading created. Actual API integration will be implemented.")
    }
    }
    
    // Convenience method for backwards compatibility
    func fetchLatestReading() async {
        // This method can be called without APIManager for simple status updates
        // The actual data fetching should be done through the other method
        print("Note: Use fetchLatestGlucoseReading(apiManager:) for actual data fetching")
    }

