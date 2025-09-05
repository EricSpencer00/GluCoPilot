import Foundation
import HealthKit

/// Protocol for abstracting HealthKit store operations
/// Allows for dependency injection and testability
protocol HealthStoreType {
    func execute(_ query: HKQuery)
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?, completion: @escaping (Bool, Error?) -> Void)
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    static func isHealthDataAvailable() -> Bool
}

/// Custom enum representing HealthKit permission states, including partial permissions
enum HealthKitPermissionState: Equatable {
    case notDetermined
    case authorized
    case denied
    case partial(authorized: Set<String>, denied: Set<String>)
    
    var isFullyAuthorized: Bool {
        if case .authorized = self {
            return true
        }
        return false
    }
}

/// Default implementation of HealthStoreType that wraps HKHealthStore
class HKHealthStoreWrapper: HealthStoreType {
    private let healthStore = HKHealthStore()
    
    func execute(_ query: HKQuery) {
        healthStore.execute(query)
    }
    
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?, completion: @escaping (Bool, Error?) -> Void) {
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead, completion: completion)
    }
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    static func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
}
