import Foundation
import SwiftUI

// Simple keychain storage class to avoid name conflicts
class KeychainStorage {
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

enum DexcomManagerError: LocalizedError {
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
    @Published var lastUpdate: Date? = nil
    
    private let keychain = KeychainStorage()
    
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
    
    func connect(username: String, password: String, isInternational: Bool, apiManager: APIManager) async throws {
        isLoading = true
        defer {
            isLoading = false
        }
        
        // Validate credentials through the API
        do {
            let isValid = try await apiManager.validateDexcomCredentials(
                username: username,
                password: password,
                isInternational: isInternational
            )
            
            if isValid {
                // Store credentials securely
                keychain.setValue(username, for: "dexcom_username")
                keychain.setValue(password, for: "dexcom_password")
                keychain.setValue(String(isInternational), for: "dexcom_is_international")
                
                isConnected = true
                
                // Fetch initial glucose reading
                try await fetchLatestGlucoseReading(apiManager: apiManager)
                
                print("Dexcom credentials validated and stored successfully.")
            } else {
                throw DexcomManagerError.invalidCredentials
            }
        } catch {
            print("Failed to validate Dexcom credentials: \(error.localizedDescription)")
            throw error
        }
    }
    
    func disconnect() {
        // Clear stored credentials
        keychain.deleteValue(for: "dexcom_username")
        keychain.deleteValue(for: "dexcom_password")
        keychain.deleteValue(for: "dexcom_is_international")
        
        isConnected = false
        latestGlucoseReading = nil
        lastUpdate = nil
    }
    
    func fetchLatestGlucoseReading(apiManager: APIManager) async throws {
        guard isConnected,
              let username = keychain.getValue(for: "dexcom_username"),
              let password = keychain.getValue(for: "dexcom_password"),
              let isInternationalString = keychain.getValue(for: "dexcom_is_international") else {
            throw DexcomManagerError.notConnected
        }
        
        let isInternational = isInternationalString == "true" || isInternationalString == "1"
        
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            let apiReading = try await apiManager.fetchLatestGlucoseReading(
                username: username,
                password: password,
                isInternational: isInternational
            )
            
            // Convert APIManagerGlucoseReading to GlucoseReading for use in the app
            let reading = GlucoseReading(
                id: UUID(),
                value: apiReading.value,
                trend: apiReading.trend,
                timestamp: apiReading.timestamp,
                unit: apiReading.unit
            )
            
            await MainActor.run {
                self.latestGlucoseReading = reading
                self.lastUpdate = Date()
            }
            
            print("Successfully fetched latest glucose reading: \(reading.value) \(reading.unit)")
        } catch {
            print("Error fetching glucose reading: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchGlucoseReadings(timeframe: String = "1d", count: Int = 100, apiManager: APIManager) async throws -> [GlucoseReading] {
        guard isConnected else {
            throw DexcomManagerError.notConnected
        }
        
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            let apiReadings = try await apiManager.fetchGlucoseReadings(timeframe: timeframe, count: count)
            
            // Convert APIManagerGlucoseReading array to GlucoseReading array
            let readings = apiReadings.map { apiReading in
                GlucoseReading(
                    id: UUID(),
                    value: apiReading.value,
                    trend: apiReading.trend,
                    timestamp: apiReading.timestamp,
                    unit: apiReading.unit
                )
            }
            
            if !readings.isEmpty {
                // Update the latest reading with the most recent one
                await MainActor.run {
                    if let mostRecent = readings.sorted(by: { $0.timestamp > $1.timestamp }).first {
                        self.latestGlucoseReading = mostRecent
                    }
                    self.lastUpdate = Date()
                }
            }
            
            print("Successfully fetched \(readings.count) glucose readings")
            return readings
        } catch {
            print("Error fetching glucose readings: \(error.localizedDescription)")
            throw error
        }
    }
}
