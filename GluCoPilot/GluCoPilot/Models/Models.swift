import Foundation
import SwiftUI

// MARK: - Glucose Data Models
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
        case "rising slightly", "fortyfiveup": return "↗"
        case "steady", "flat": return "→"
        case "falling slightly", "fortyfivedown": return "↘"
        case "falling", "singledown": return "↘"
        case "falling rapidly", "doubledown": return "⇊"
        default: return "?"
        }
    }
    
    var isInRange: Bool {
        return value >= 70 && value <= 180
    }
    
    var isHigh: Bool {
        return value > 180
    }
    
    var isLow: Bool {
        return value < 70
    }
}

// MARK: - Health Data Models
struct HealthData: Codable {
    let steps: Int
    let activeCalories: Int
    let averageHeartRate: Int
    let workouts: [WorkoutData]
    let sleepHours: Double
    let nutrition: NutritionData
    let startDate: Date
    let endDate: Date
}

struct WorkoutData: Codable {
    let type: String
    let duration: TimeInterval
    let calories: Double
    let startDate: Date
    let endDate: Date
}

struct NutritionData: Codable {
    let calories: Double
    let carbohydrates: Double
    let protein: Double
    let fat: Double
}

// MARK: - AI Insights Models
struct AIInsight: Identifiable, Codable {
    var id: UUID { UUID() }
    let title: String
    let description: String
    let category: String
    let priority: Priority
    let actionItems: [String]
    let timestamp: Date
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    var icon: String {
        switch category.lowercased() {
        case "glucose": return "drop.fill"
        case "activity": return "figure.walk"
        case "nutrition": return "fork.knife"
        case "sleep": return "bed.double.fill"
        case "general": return "lightbulb.fill"
        default: return "info.circle.fill"
        }
    }
    
    var priorityColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - API Response Models
struct SyncResults: Codable {
    let recordCount: Int
    let stepCount: Int
    let workoutCount: Int
    let sleepHours: Double
}

// MARK: - Error Models
enum HealthKitError: LocalizedError {
    case notAvailable
    case invalidType
    case authorizationDenied
    case typeNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .invalidType:
            return "Invalid HealthKit data type"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .typeNotFound:
            return "HealthKit data type not found"
        }
    }
}

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
