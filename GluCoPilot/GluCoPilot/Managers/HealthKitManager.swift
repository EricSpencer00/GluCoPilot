import Foundation
import HealthKit
import SwiftUI

// MARK: - HealthKit Models
struct HealthKitManagerHealthData: Codable {
    let steps: Int
    let activeCalories: Int
    let averageHeartRate: Int
    let workouts: [HealthKitManagerWorkoutData]
    let sleepHours: Double
    let nutrition: [HealthKitManagerNutritionData]
    let glucose: [HealthKitGlucoseSample]
}

struct HealthKitManagerWorkoutData: Codable {
    let name: String
    let duration: Double
    let calories: Double
    let startDate: Date
    let endDate: Date
}

struct HealthKitManagerNutritionData: Codable {
    let name: String
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let timestamp: Date
}

struct HealthKitGlucoseSample: Codable {
    let value: Double
    let unit: String
    let timestamp: Date
}

// MARK: - Error Types
enum HealthKitManagerError: Error {
    case notAvailable
    case authorizationFailed
    case dataFetchFailed
}

@MainActor
class HealthKitManager: ObservableObject {
    @Published var isHealthKitAvailable = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    // Published health metrics for UI
    @Published var todaySteps: Int = 0
    @Published var activeMinutes: Double = 0
    @Published var sleepHours: Double = 0
    @Published var averageHeartRate: Double = 0
    
    private let healthStore = HKHealthStore()
    
    // Health data types we want to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
    ]
    
    init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }
    
    func requestHealthKitPermissions() {
        guard isHealthKitAvailable else {
            print("HealthKit is not available on this device")
            return
        }
        // Request authorization. In some dev setups (simulator or mismatched bundle id)
        // HealthKit may return an error like "Failed to look up source with bundle identifier".
        // We log actionable hints so developers can correct Info.plist/product bundle settings.
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization granted")
                    self?.authorizationStatus = .sharingAuthorized
                    // Update published properties after getting permissions
                    Task {
                        await self?.updatePublishedProperties()
                    }
                } else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    print("HealthKit authorization denied: \(message)")
                    // Common actionable error: Failed to look up source with bundle identifier
                    if message.contains("Failed to look up source with bundle identifier") {
                        print("HealthKit error indicates the app's bundle identifier doesn't match a registered source.\nPlease ensure the app's Product Bundle Identifier (in Xcode) and the installed app's bundle id match.\nAlso confirm HealthKit entitlements and Info.plist usage descriptions are present.")
#if targetEnvironment(simulator)
                        print("Running in simulator: HealthKit is not fully supported. Falling back to stubbed values for UI testing.")
                        self?.authorizationStatus = .sharingAuthorized
                        Task {
                            await self?.updatePublishedProperties()
                        }
#else
                        self?.authorizationStatus = .sharingDenied
#endif
                    } else {
                        self?.authorizationStatus = .sharingDenied
                    }
                }
            }
        }
    }
    
    func updatePublishedProperties() async {
        do {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            
            // Update steps
            let steps = try await fetchStepCount(from: startOfDay, to: Date())
            await MainActor.run {
                self.todaySteps = steps
            }
            
            // Update heart rate
            let heartRate = try await fetchHeartRate(from: startOfDay, to: Date())
            await MainActor.run {
                self.averageHeartRate = Double(heartRate)
            }
            
            // Update sleep (previous night)
            let sleepStart = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay)!
            let sleep = try await fetchSleepData(from: sleepStart, to: startOfDay)
            await MainActor.run {
                self.sleepHours = sleep
            }
            
            // Update active minutes (approximate from calories)
            let calories = try await fetchActiveCalories(from: startOfDay, to: Date())
            await MainActor.run {
                self.activeMinutes = Double(calories) / 5.0 // Rough approximation
            }
        } catch {
            print("Error updating published properties: \(error)")
        }
    }
    
    func fetchLast24HoursData() async throws -> HealthKitManagerHealthData {
        guard isHealthKitAvailable else {
            throw HealthKitManagerError.notAvailable
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        
        async let steps = fetchStepCount(from: startDate, to: endDate)
        async let calories = fetchActiveCalories(from: startDate, to: endDate)
        async let heartRate = fetchHeartRate(from: startDate, to: endDate)
        async let workouts = fetchWorkouts(from: startDate, to: endDate)
        async let sleep = fetchSleepData(from: startDate, to: endDate)
        async let nutrition = fetchNutritionData(from: startDate, to: endDate)
        async let glucoseSamples = fetchGlucoseSamples(from: startDate, to: endDate)
        
        let healthData = HealthKitManagerHealthData(
            steps: try await steps,
            activeCalories: try await calories,
            averageHeartRate: try await heartRate,
            workouts: try await workouts,
            sleepHours: try await sleep,
            nutrition: [try await nutrition],
            glucose: try await glucoseSamples
        )
        
        return healthData
    }
    
    private func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No step count data available for the specified time range. Returning 0.")
#endif
                        continuation.resume(returning: 0)
                    } else {
                        print("Error fetching step count: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: Int(steps))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveCalories(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No active calories data available for the specified time range. Returning 0.")
#endif
                        continuation.resume(returning: 0)
                    } else {
                        print("Error fetching active calories: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    continuation.resume(returning: Int(calories))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRate(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No heart rate data available for the specified time range. Returning 0")
#endif
                        continuation.resume(returning: 0)
                    } else {
                        print("Error fetching heart rate: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let heartRate = result?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    continuation.resume(returning: Int(heartRate))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthKitManagerWorkoutData] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No workout data available for the specified time range. Returning empty array.")
#endif
                        continuation.resume(returning: [])
                    } else {
                        print("Error fetching workouts: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let workouts = (samples as? [HKWorkout])?.map { workout in
                        HealthKitManagerWorkoutData(
                            name: workout.workoutActivityType.name,
                            duration: workout.duration,
                            calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                            startDate: workout.startDate,
                            endDate: workout.endDate
                        )
                    } ?? []
                    continuation.resume(returning: workouts)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitManagerError.dataFetchFailed
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No sleep data available for the specified time range. Returning 0")
#endif
                        continuation.resume(returning: 0.0)
                    } else {
                        print("Error fetching sleep data: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let sleepSamples = samples as? [HKCategorySample] ?? []
                    let totalSleepTime = sleepSamples.reduce(0) { total, sample in
                        return total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    let sleepHours = totalSleepTime / 3600
                    continuation.resume(returning: sleepHours)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchNutritionData(from startDate: Date, to endDate: Date) async throws -> HealthKitManagerNutritionData {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        async let calories = fetchNutritionValue(.dietaryEnergyConsumed, predicate: predicate, unit: .kilocalorie())
        async let carbs = fetchNutritionValue(.dietaryCarbohydrates, predicate: predicate, unit: .gram())
        async let protein = fetchNutritionValue(.dietaryProtein, predicate: predicate, unit: .gram())
        async let fat = fetchNutritionValue(.dietaryFatTotal, predicate: predicate, unit: .gram())
        
        return HealthKitManagerNutritionData(
            name: "Daily Nutrition",
            calories: try await calories,
            carbs: try await carbs,
            protein: try await protein,
            fat: try await fat,
            timestamp: Date()
        )
    }
    
    private func fetchNutritionValue(_ identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, unit: HKUnit) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitManagerError.dataFetchFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    // Handle the specific "No data available" error gracefully
                    if (error as NSError).domain == "com.apple.healthkit" && (error as NSError).code == 11 {
#if DEBUG
                        print("No nutrition data available for \(identifier) in the specified time range. Returning 0.")
#endif
                        continuation.resume(returning: 0.0)
                    } else {
                        print("Error fetching nutrition data for \(identifier): \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: value)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchGlucoseSamples(from startDate: Date, to endDate: Date) async throws -> [HealthKitGlucoseSample] {
        // Attempt to read blood glucose samples (HKQuantityTypeIdentifier.bloodGlucose)
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            // Not available on device / simulator: return empty array
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: glucoseType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                // Handle errors explicitly so `samples` is only used when present
                if let error = error {
#if DEBUG
                    print("Error fetching glucose samples: \(error.localizedDescription)")
#endif
                    continuation.resume(returning: [HealthKitGlucoseSample]())
                    return
                }
                
                let glucoseSamples = (samples as? [HKQuantitySample])?.map { sample in
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                    return HealthKitGlucoseSample(value: value, unit: "mg/dL", timestamp: sample.startDate)
                } ?? [HealthKitGlucoseSample]()
                
                continuation.resume(returning: glucoseSamples)
            }
            
            healthStore.execute(query)
        }
    }

}

// MARK: - Extensions
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .other: return "Other"
        default: return "Workout"
        }
    }
}
