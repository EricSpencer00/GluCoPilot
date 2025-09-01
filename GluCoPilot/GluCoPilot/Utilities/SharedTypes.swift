import Foundation
import SwiftUI

// MARK: - Core Data Models
struct GlucoseReading: Codable, Identifiable {
    var id = UUID()
    let value: Int
    let trend: String
    let timestamp: Date
    let unit: String
}

struct HealthData: Codable {
    let glucose: [GlucoseReading]
    let workouts: [WorkoutData]?
    let nutrition: [NutritionData]?
    let timestamp: Date
}

struct WorkoutData: Codable, Identifiable, Equatable {
    var id = UUID()
    let type: String
    let duration: TimeInterval
    let calories: Double?
    let startDate: Date
    let endDate: Date
}

struct NutritionData: Codable, Identifiable {
    var id = UUID()
    let name: String
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let timestamp: Date
}

extension NutritionData: Equatable {
    static func == (lhs: NutritionData, rhs: NutritionData) -> Bool {
        return lhs.id == rhs.id
    }
}

// Backwards-compatible alias: some views expect a `FoodEntry` type
typealias FoodEntry = NutritionData

struct AIInsight: Codable, Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let type: InsightType
    let priority: InsightPriority
    let timestamp: Date
    let actionItems: [String]
    let dataPoints: [String: Double]
    
    var category: String {
        return type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var icon: String {
        return type.icon
    }
    
    var priorityColor: Color {
        return priority.color
    }
    
    enum InsightType: String, Codable, CaseIterable {
        case bloodSugar = "blood_sugar"
        case diet = "diet"
        case exercise = "exercise"
        case medication = "medication"
        case lifestyle = "lifestyle"
        case pattern = "pattern"
        
        var icon: String {
            switch self {
            case .bloodSugar: return "drop.fill"
            case .diet: return "fork.knife"
            case .exercise: return "figure.run"
            case .medication: return "pills.fill"
            case .lifestyle: return "heart.fill"
            case .pattern: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    enum InsightPriority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
}

struct SyncResults: Codable {
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
    
    var recordCount: Int {
        return totalSyncedItems
    }
}

// MARK: - Error Types
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case rateLimited
    case maintenanceMode
    
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
        }
    }
}

enum DexcomError: Error, LocalizedError {
    case notConnected
    case invalidCredentials
    case authenticationFailed
    case networkError(Error)
    case dataUnavailable
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Dexcom account not connected"
        case .invalidCredentials:
            return "Invalid Dexcom credentials"
        case .authenticationFailed:
            return "Dexcom authentication failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .dataUnavailable:
            return "Glucose data unavailable"
        case .rateLimited:
            return "Too many requests. Please try again later."
        }
    }
}

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case invalidType
    case noData
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized"
        case .invalidType:
            return "Invalid HealthKit data type"
        case .noData:
            return "No data available"
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
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
