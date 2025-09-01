import Foundation
import HealthKit
import SwiftUI

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
                    print("HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
                    self?.authorizationStatus = .sharingDenied
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
    
    func fetchLast24HoursData() async throws -> HealthData {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        
        async let steps = fetchStepCount(from: startDate, to: endDate)
        async let calories = fetchActiveCalories(from: startDate, to: endDate)
        async let heartRate = fetchHeartRate(from: startDate, to: endDate)
        async let workouts = fetchWorkouts(from: startDate, to: endDate)
        async let sleep = fetchSleepData(from: startDate, to: endDate)
        async let nutrition = fetchNutritionData(from: startDate, to: endDate)
        
        let healthData = HealthData(
            steps: try await steps,
            activeCalories: try await calories,
            averageHeartRate: try await heartRate,
            workouts: try await workouts,
            sleepHours: try await sleep,
            nutrition: try await nutrition,
            startDate: startDate,
            endDate: endDate
        )
        
        return healthData
    }
    
    private func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if let error = error {
                print("Error fetching step count: \(error.localizedDescription)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
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
                    continuation.resume(throwing: error)
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
                    continuation.resume(throwing: error)
                } else {
                    let heartRate = result?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    continuation.resume(returning: Int(heartRate))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout])?.map { workout in
                        WorkoutData(
                            type: workout.workoutActivityType.name,
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
            throw HealthKitError.invalidType
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
                    continuation.resume(throwing: error)
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
    
    private func fetchNutritionData(from startDate: Date, to endDate: Date) async throws -> NutritionData {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        async let calories = fetchNutritionValue(.dietaryEnergyConsumed, predicate: predicate, unit: .kilocalorie())
        async let carbs = fetchNutritionValue(.dietaryCarbohydrates, predicate: predicate, unit: .gram())
        async let protein = fetchNutritionValue(.dietaryProtein, predicate: predicate, unit: .gram())
        async let fat = fetchNutritionValue(.dietaryFatTotal, predicate: predicate, unit: .gram())
        
        return NutritionData(
            calories: try await calories,
            carbohydrates: try await carbs,
            protein: try await protein,
            fat: try await fat
        )
    }
    
    private func fetchNutritionValue(_ identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, unit: HKUnit) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.invalidType
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: value)
                }
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
