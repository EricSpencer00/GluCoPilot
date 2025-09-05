import XCTest
import HealthKit
@testable import GluCoPilot

/// Mock implementation of HealthStoreType for testing
class MockHealthStore: HealthStoreType {
    // Configurable test behaviors
    var shouldSucceedAuthorization = true
    var mockPermissionState: HealthKitPermissionState = .notDetermined
    var mockHealthData = HealthKitManagerHealthData(
        steps: 8000,
        activeCalories: 350,
        averageHeartRate: 75,
        workouts: [],
        sleepHours: 7.5,
        nutrition: [],
        glucose: []
    )
    
    // Track which queries were executed
    var executedQueries: [HKQuery] = []
    
    // MARK: - HealthStoreType Implementation
    
    func execute(_ query: HKQuery) {
        executedQueries.append(query)
        
        // Handle different query types
        if let sampleQuery = query as? HKSampleQuery {
            let completion = sampleQuery.resultsHandler
            completion(query, [], nil)
        }
    }
    
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?, completion: @escaping (Bool, Error?) -> Void) {
        // Simulate authorization response
        if shouldSucceedAuthorization {
            completion(true, nil)
        } else {
            completion(false, NSError(domain: "MockHealthStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock authorization failed"]))
        }
    }
    
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        switch mockPermissionState {
        case .authorized:
            return .sharingAuthorized
        case .denied:
            return .sharingDenied
        case .notDetermined:
            return .notDetermined
        case .partial:
            // For simplicity, just return notDetermined in the partial case
            return .notDetermined
        }
    }
    
    static func isHealthDataAvailable() -> Bool {
        return true // Always available in tests
    }
}

final class HealthKitManagerTests: XCTestCase {
    var mockHealthStore: MockHealthStore!
    var healthKitManager: HealthKitManager!

    override func setUp() {
        super.setUp()
        mockHealthStore = MockHealthStore()
        healthKitManager = HealthKitManager(healthStore: mockHealthStore)
    }

    override func tearDown() {
        mockHealthStore = nil
        healthKitManager = nil
        super.tearDown()
    }
    
    func testRequestPermissionsSuccess() async {
        // Configure mock to succeed
        mockHealthStore.shouldSucceedAuthorization = true
        
        // Request permissions
        let result = await healthKitManager.requestPermissions()
        
        // Check result
        switch result {
        case .success:
            // Verify state updates
            XCTAssertEqual(healthKitManager.permissionState, .authorized)
            XCTAssertEqual(healthKitManager.authorizationStatus, .sharingAuthorized)
            XCTAssertTrue(healthKitManager.hasReadAccess)
        case .failure(let error):
            XCTFail("Permission request should have succeeded but failed with: \(error.localizedDescription)")
        }
    }
    
    func testRequestPermissionsFailure() async {
        // Configure mock to fail
        mockHealthStore.shouldSucceedAuthorization = false
        
        // Request permissions
        let result = await healthKitManager.requestPermissions()
        
        // Check result
        switch result {
        case .success:
            XCTFail("Permission request should have failed but succeeded")
        case .failure(let error):
            // Verify error and state
            XCTAssertEqual(healthKitManager.permissionState, .denied)
            XCTAssertEqual(healthKitManager.authorizationStatus, .sharingDenied)
            XCTAssertFalse(healthKitManager.hasReadAccess)
            
            if case .authorizationFailed = error {
                // Expected error type
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
}
