import Foundation
import HealthKit
import SwiftUI
import UIKit
import WidgetKit

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

struct HealthKitManagerWorkoutData: Codable, Equatable {
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
    // Toggle to control whether HealthKit permission/debug logs are printed
    @AppStorage("showHealthKitPermissionLogs") var showPermissionLogs: Bool = false
    
    private let healthStore = HKHealthStore()
    // Track active queries for proper cleanup
    private var activeQueries: [HKQuery] = []
    
    // Track whether we've already logged a granted message to avoid duplicates
    private var hasLoggedAuthorizationGranted = false
    // Observer token used to defer permission requests until app becomes active
    private var pendingAuthorizationObserver: Any?
    
    // Health data types we want to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        // Include blood glucose to allow CGM/SMBG readings in-app
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
    ]

    // Health data types we may write back to HealthKit (used for storing AI insights)
    // We use a category sample (mindfulSession) as a cross-SDK-compatible container for JSON metadata.
    private var writeTypes: Set<HKSampleType> {
        var s: Set<HKSampleType> = []
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            s.insert(mindful)
        }
        return s
    }
    
    // Add a new property to track read permissions
    // Persist read permission across instances so we don't re-prompt unnecessarily
    @AppStorage("hk_read_permissions_granted") private var readPermissionsGrantedStored: Bool = false
    private var readPermissionsGranted: Bool = false
    // Anchor persistence key for incremental glucose sync
    private let glucoseAnchorKey = "hk_glucose_anchor_v1"
    
    // Published latest glucose sample (UI can observe this)
    @Published var latestGlucoseSample: HealthKitGlucoseSample?
    // Debug: last time we explicitly refreshed from HealthKit
    @Published var lastHealthKitRefresh: Date?
    // Publish the most recent authorization error message (if any) for UI/diagnostics
    @Published var lastAuthorizationErrorMessage: String?
    // Diagnostics output for debugging HealthKit behavior
    @Published var debugReport: String? = nil
    // Track cooldown period for refresh (15 minutes)
    @AppStorage("last_refresh_timestamp") private var lastRefreshTimestamp: Double = 0
    // Whether refresh is currently on cooldown
    @Published var isRefreshOnCooldown: Bool = false
    
    init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        // Initialize read-permissions flag from persisted storage
        self.readPermissionsGranted = readPermissionsGrantedStored
        // Reflect persisted read-permission in authorizationStatus so UI can observe it
        if self.readPermissionsGranted {
            self.authorizationStatus = .sharingAuthorized
            self.hasLoggedAuthorizationGranted = true
        }
        
        // Check if we're on cooldown
        let now = Date()
        let lastRefresh = Date(timeIntervalSince1970: lastRefreshTimestamp)
        let cooldownPeriod: TimeInterval = 15 * 60 // 15 minutes
        self.isRefreshOnCooldown = now.timeIntervalSince(lastRefresh) < cooldownPeriod
    }
    
    
    // Note: HealthKit does not expose a public API to determine READ authorization per type at runtime.
    // authorizationStatus(for:) only reflects WRITE permission. Do NOT use it to gate read queries.
    // Instead, perform queries and handle empty/no-data responses gracefully.
    
    func requestHealthKitPermissions() {
        guard isHealthKitAvailable else {
            print("HealthKit is not available on this device")
            authorizationStatus = .notDetermined
            return
        }
        
        // Request all permissions at once
        if showPermissionLogs {
            print("Requesting HealthKit read permissions...")
        }
        
        // IMPORTANT: Always request authorization to ensure the iOS permission dialog shows
        // Do not check authorization status beforehand for READ permissions
        // Runtime check: print whether we're on the main thread and the app state
        print("[HealthKitManager] requestHealthKitPermissions called. mainThread=\(Thread.isMainThread) applicationState=\(UIApplication.shared.applicationState.rawValue)")
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            print("[HealthKitManager] active window scene state=\(scene.activationState.rawValue)")
        }
        // If app is not active, defer the request to avoid system UI suppression.
        if UIApplication.shared.applicationState != .active {
            print("[HealthKitManager] App not active; deferring HealthKit permission request until app becomes active")
            // Remove any existing observer to avoid duplicates
            if let token = pendingAuthorizationObserver {
                NotificationCenter.default.removeObserver(token)
                pendingAuthorizationObserver = nil
            }
            // Observe didBecomeActive and re-attempt once
            pendingAuthorizationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.pendingAuthorizationObserver = nil
                print("[HealthKitManager] didBecomeActive observed — retrying HealthKit permission request")
                self?.requestHealthKitPermissions()
            }
            return
        }

        // Detailed logging: print the exact sets we're passing to HealthKit
        do {
            let readNames = readTypes.compactMap { type -> String? in
                if let q = type as? HKQuantityType { return q.identifier }
                if let c = type as? HKCategoryType { return c.identifier }
                return String(describing: type)
            }
            print("[HealthKitManager] requestAuthorization called. readTypes: \(readNames)")
        }
    healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            print("[HealthKitManager] requestAuthorization completion invoked. success=\(success) error=\(String(describing: error))")
            DispatchQueue.main.async {
                if success {
                    print("[HealthKitManager] Authorization success path")
                    if self?.showPermissionLogs ?? false {
                        print("HealthKit authorization granted successfully!")
                    }
                    self?.hasLoggedAuthorizationGranted = true
                    self?.readPermissionsGranted = true
                    self?.readPermissionsGrantedStored = true
                    self?.authorizationStatus = .sharingAuthorized
                    // Clear any previous auth error
                    self?.lastAuthorizationErrorMessage = nil
                    
                    // Start observing glucose updates so app receives new samples in foreground & background
                    self?.startGlucoseObserving()
                    Task {
                        await self?.updatePublishedProperties()
                    }
                } else {
                    let message = error?.localizedDescription ?? "Unknown error"
                    print("[HealthKitManager] Authorization failed message: \(message)")
                    self?.lastAuthorizationErrorMessage = message
                    if self?.showPermissionLogs ?? false {
                        print("HealthKit authorization denied: \(message)")
                    }
                    self?.hasLoggedAuthorizationGranted = false
                    self?.readPermissionsGranted = false
                    if message.contains("Failed to look up source with bundle identifier") {
                        print("HealthKit error indicates the app's bundle identifier doesn't match a registered source.\nPlease ensure the app's Product Bundle Identifier (in Xcode) and the installed app's bundle id match.\nAlso confirm HealthKit entitlements and Info.plist usage descriptions are present.")
#if DEBUG
                        print("[HealthKitManager] saved authorization error for UI: \(message)")
#endif
#if targetEnvironment(simulator)
                        print("Running in simulator: HealthKit is not fully supported. Falling back to stubbed values for UI testing.")
                        self?.authorizationStatus = .sharingAuthorized
                        self?.readPermissionsGranted = true
                        Task {
                            await self?.updatePublishedProperties()
                        }
#else
                        self?.authorizationStatus = .sharingDenied
#endif
                    } else {
                        self?.authorizationStatus = .sharingDenied
                        self?.readPermissionsGranted = false
                        self?.readPermissionsGrantedStored = false
                    }
                }
            }
        }
    }

    /// Debug helper: request authorization for only blood glucose (minimal set) to test whether the system
    /// permission sheet appears. This reduces the surface area of the permission dialog and helps
    /// determine if asking for many types at once is causing suppression.
    func requestHealthKitPermissionsMinimal() {
        guard isHealthKitAvailable else {
            print("[HealthKitManager] Minimal request: HealthKit not available")
            return
        }

        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            print("[HealthKitManager] Minimal request: bloodGlucose type unavailable")
            return
        }

        // If app is not active, defer until it is to avoid suppression
        if UIApplication.shared.applicationState != .active {
            print("[HealthKitManager] Minimal request: app not active; deferring until didBecomeActive")
            if let token = pendingAuthorizationObserver {
                NotificationCenter.default.removeObserver(token)
                pendingAuthorizationObserver = nil
            }
            pendingAuthorizationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.pendingAuthorizationObserver = nil
                print("[HealthKitManager] Minimal request: didBecomeActive observed — retrying minimal permission request")
                self?.requestHealthKitPermissionsMinimal()
            }
            return
        }

        print("[HealthKitManager] Minimal requestAuthorization called for bloodGlucose only. mainThread=\(Thread.isMainThread) applicationState=\(UIApplication.shared.applicationState.rawValue)")
        healthStore.requestAuthorization(toShare: nil, read: [glucoseType]) { success, error in
            print("[HealthKitManager] Minimal requestAuthorization completion. success=\(success) error=\(String(describing: error)) mainThread=\(Thread.isMainThread) applicationState=\(UIApplication.shared.applicationState.rawValue)")
            DispatchQueue.main.async {
                if success {
                    self.authorizationStatus = .sharingAuthorized
                    self.readPermissionsGranted = true
                    self.readPermissionsGrantedStored = true
                    self.startGlucoseObserving()
                } else {
                    self.lastAuthorizationErrorMessage = error?.localizedDescription
                }
            }
        }
    }

    /// Run a compact diagnostics report that prints authorization/read state and recent glucose/source counts.
    func runDiagnostics() async {
        var out: [String] = []
        out.append("Diagnostics run at: \(Date())")
        out.append("Bundle: \(Bundle.main.bundleIdentifier ?? "-")")
        out.append("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")

        // Authorization status per-type (note: authorizationStatus(for:) reflects write status)
        let typesToCheck: [(String, HKSampleType?)] = [
            ("bloodGlucose", HKObjectType.quantityType(forIdentifier: .bloodGlucose)),
            ("stepCount", HKObjectType.quantityType(forIdentifier: .stepCount)),
            ("activeEnergyBurned", HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)),
            ("heartRate", HKObjectType.quantityType(forIdentifier: .heartRate)),
            ("sleepAnalysis", HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
        ]

        for (name, sampleType) in typesToCheck {
            if let t = sampleType {
                let status = healthStore.authorizationStatus(for: t)
                out.append("authStatus(\(name)): \(status)")
            } else {
                out.append("authStatus(\(name)): <type unavailable>")
            }
        }

        // getRequestStatusForAuthorization
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Some SDK variants expect non-optional Sets; pass empty typed sets when needed.
            let emptyShare: Set<HKSampleType> = []
            let readSet: Set<HKObjectType> = readTypes
            healthStore.getRequestStatusForAuthorization(toShare: emptyShare, read: readSet) { status, error in
                if let err = error {
                    out.append("getRequestStatusForAuthorization error: \(err.localizedDescription)")
                } else {
                    out.append("requestStatus: \(status.rawValue) (\(status))")
                }
                continuation.resume()
            }
        }

        // Fetch some glucose diagnostics
        if let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            // source list
            let sources = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
                let query = HKSourceQuery(sampleType: glucoseType, samplePredicate: nil) { _, sourcesOrNil, error in
                    if let error = error {
                        continuation.resume(returning: ["source query error: \(error.localizedDescription)"])
                        return
                    }
                    let list = (sourcesOrNil ?? []).map { s in
                        return "name:\(s.name) bundle:\(s.bundleIdentifier ?? "-")"
                    }
                    continuation.resume(returning: list)
                }
                self.healthStore.execute(query)
            }
            out.append("glucose sources: \(sources.count) entries")
            out.append(contentsOf: sources.prefix(20))

            // sample count
            do {
                let count = try await fetchGlucoseSampleCount()
                out.append("glucose sample count: \(count)")
            } catch {
                out.append("glucose sample count error: \(error.localizedDescription)")
            }

            // recent samples (limit 10)
            let recent = try? await fetchRecentGlucoseSamples(limit: 10)
            if let recent = recent {
                out.append("recent glucose sample lines: \(recent.count)")
                out.append(contentsOf: recent.prefix(20))
            } else {
                out.append("recent glucose sample fetch: failed or empty")
            }
        } else {
            out.append("bloodGlucose type missing on device")
        }

        // Publish final report
        let report = out.joined(separator: "\n")
        await MainActor.run {
            self.debugReport = report
            if self.showPermissionLogs {
                print(report)
            }
        }
    }
    
    /// Validates the current permission status directly from HealthKit and updates internal flags
    /// Returns true if permissions are authorized
    func validatePermissionStatus() -> Bool {
        guard isHealthKitAvailable else {
            authorizationStatus = .notDetermined
            return false
        }
        
        // Try to get authorization status for one of our required types
        if let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            let status = healthStore.authorizationStatus(for: glucoseType)
            
            // For READ permissions, we need to also check our stored flag because 
            // HealthKit doesn't expose a direct way to check READ permissions
            let isAuthorized = status == .sharingAuthorized || readPermissionsGrantedStored
            
            // If status is .notDetermined, we definitely need to request permissions
            if status == .notDetermined {
                if showPermissionLogs {
                    print("HealthKit authorization status is not determined yet")
                }
                readPermissionsGranted = false
                readPermissionsGrantedStored = false
                authorizationStatus = .notDetermined
                return false
            }
            
            // Update internal state if needed
            if isAuthorized != readPermissionsGranted {
                if showPermissionLogs {
                    print("Updating permission state: HealthKit=\(status), internal=\(readPermissionsGranted) to isAuthorized=\(isAuthorized)")
                }
                readPermissionsGranted = isAuthorized
                readPermissionsGrantedStored = isAuthorized
                authorizationStatus = isAuthorized ? .sharingAuthorized : .sharingDenied
            }
            
            return isAuthorized
        }
        
        return false
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
        
        // Validate permission status
        let isAuthorized = validatePermissionStatus()
        if !isAuthorized {
            throw HealthKitManagerError.authorizationFailed
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
    
    /// Debug helper: fetch recent blood glucose samples with per-sample details for inspection
    func fetchRecentGlucoseSamples(limit: Int = 100, from startDate: Date? = nil, to endDate: Date = Date()) async throws -> [String] {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            return []
        }
        // Do not gate read access by write authorization status; perform the query and handle empty results.
        
    // Default to last 24 hours when startDate is not provided
    let fromDate = startDate ?? Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: fromDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: glucoseType,
                                      predicate: predicate,
                                      limit: limit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error = error {
#if DEBUG
                    print("Error fetching glucose samples: \(error.localizedDescription)")
#endif
                    continuation.resume(returning: [])
                    return
                }
                
                let formatted: [String] = (samples as? [HKQuantitySample])?.map { sample in
                    // Convert to mg/dL (common) and mmol/L
                    let mgdl = sample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                    let mmol = mgdl / 18.0182
                    let mmolStr = String(format: "%.1f", mmol)
                    let source = sample.sourceRevision.source.name
                    let bundle = sample.sourceRevision.source.bundleIdentifier
                    let device = sample.device?.name ?? "-"
                    let meta = sample.metadata ?? [:]
                    
                    return "ts:\(sample.startDate) mg/dL:\(Int(round(mgdl))) mmol/L:\(mmolStr) source:\(source) bundle:\(bundle) device:\(device) metadata:\(meta)"
                } ?? []
                
                continuation.resume(returning: formatted)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Return authorization status for common types (WRITE status only; READ is not exposed by HealthKit)
    func getAuthorizationStatusReport() -> [String] {
        var report: [String] = []
        // Use the readPermissionsGranted flag to determine status
        let statusString = self.readPermissionsGranted ? "2 (read:authorized)" : "1 (read:denied)"
        
        if let t = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            report.append("bloodGlucose (READ): \(statusString)")
        }
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) {
            report.append("stepCount (READ): \(statusString)")
        }
        if let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            report.append("activeEnergyBurned (READ): \(statusString)")
        }
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) {
            report.append("heartRate (READ): \(statusString)")
        }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            report.append("sleepAnalysis (READ): \(statusString)")
        }
        report.append("workout (READ): \(statusString)")
        
        return report
    }
    
    /// Debug helper: fetch writer sources for several common sample types (permissive)
    func fetchSourcesReportAll() async -> [String] {
        var out: [String] = []
        
        let typeIdentifiers: [HKSampleType?] = [
            HKObjectType.quantityType(forIdentifier: .bloodGlucose),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        ]
        
        for t in typeIdentifiers {
            guard let sampleType = t else { continue }
            let typeName: String
            if let q = sampleType as? HKQuantityType {
                // identifier may be a String or an enum depending on SDK; stringify safely
                typeName = "\(q.identifier)"
            } else if let c = sampleType as? HKCategoryType {
                typeName = "\(c.identifier)"
            } else {
                typeName = "unknownType"
            }
            
            let sources = await withCheckedContinuation { continuation in
                let query = HKSourceQuery(sampleType: sampleType, samplePredicate: nil) { _, sourcesOrNil, error in
                    if let error = error {
                        continuation.resume(returning: ["error: \(typeName): \(error.localizedDescription)"])
                        return
                    }
                    
                    let list = (sourcesOrNil ?? []).map { s in
                        return "name:\(s.name) bundle:\(s.bundleIdentifier ?? "-")"
                    }
                    continuation.resume(returning: list)
                }
                healthStore.execute(query)
            }
            
            if sources.isEmpty {
                out.append("\(typeName): <no sources>")
            } else {
                out.append("\(typeName): \(sources.count) sources")
                out.append(contentsOf: sources.prefix(20))
            }
        }
        
        return out
    }
    
    // MARK: - Backwards-compatible debug helpers used by legacy debug UI
    func getAppIdentityReport() -> [String] {
        var out: [String] = []
        let bundle = Bundle.main.bundleIdentifier ?? "-"
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "-")
        out.append("bundleIdentifier: \(bundle)")
        out.append("appName: \(name)")
#if targetEnvironment(simulator)
        out.append("environment: simulator")
#else
        out.append("environment: device")
#endif
        out.append("healthKitAvailable: \(isHealthKitAvailable)")
        out.append("readPermissionsGranted: \(readPermissionsGranted)")
        return out
    }
    
    func fetchAnyGlucoseSamples(limit: Int = 200) async throws -> [String] {
        // Reuse the existing recent glucose samples helper (permissive)
        return try await fetchRecentGlucoseSamples(limit: limit)
    }
    
    func fetchGlucoseSourcesReport() async -> [String] {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return [] }
        
        return await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: glucoseType, samplePredicate: nil) { _, sourcesOrNil, error in
                if let error = error {
                    continuation.resume(returning: ["error: \(error.localizedDescription)"])
                    return
                }
                
                let list = (sourcesOrNil ?? []).map { s in
                    return "name:\(s.name) bundle:\(s.bundleIdentifier ?? "-")"
                }
                continuation.resume(returning: list)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch recent HKCorrelation "food" records and return a human-readable summary.
    /// This helps verify whether apps like MyFitnessPal are writing food/nutrition data into HealthKit.
    func fetchRecentFoodCorrelations(limit: Int = 50, from startDate: Date? = nil, to endDate: Date = Date()) async -> [String] {
        guard let foodType = HKObjectType.correlationType(forIdentifier: .food) else {
            return ["food correlation type not available on this device"]
        }

    // Default to last 24 hours when startDate is not provided
    let fromDate = startDate ?? Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: fromDate, end: endDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: foodType,
                                      predicate: predicate,
                                      limit: limit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: ["error: \(error.localizedDescription)"])
                    return
                }

                let formatted: [String] = (samples as? [HKCorrelation])?.map { corr in
                    let start = corr.startDate
                    let source = corr.sourceRevision.source.name
                    let bundle = corr.sourceRevision.source.bundleIdentifier ?? "-"
                    // Summarize contained samples (quantity samples usually hold nutrient values)
                    let components = corr.objects.map { obj -> String in
                        if let q = obj as? HKQuantitySample {
                            let id = (q.quantityType as? HKQuantityType)?.identifier ?? "qty"
                            // Try grams then fallback to raw double
                            let v = q.quantity.doubleValue(for: .gram())
                            return "\(id):\(String(format: "%.1f", v))"
                        } else {
                            return String(describing: type(of: obj))
                        }
                    }
                    return "ts:\(start) source:\(source) bundle:\(bundle) items:[\(components.joined(separator: ","))] metadata:\(corr.metadata ?? [:])"
                } ?? ["<no food correlations found>"]

                continuation.resume(returning: formatted)
            }

            healthStore.execute(query)
        }
    }

    /// Returns structured FoodItem-like summaries from recent HKCorrelation(food) records.
    /// Aggregates nutrient quantity samples (kcal for energy, grams for macros) for accuracy.
    func fetchRecentFoodItems(limit: Int = 50, from startDate: Date? = nil, to endDate: Date = Date()) async -> [[String: Any]] {
        guard let foodType = HKObjectType.correlationType(forIdentifier: .food) else {
            return [["error": "food correlation type not available"]]
        }

        let fromDate = startDate ?? Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: fromDate, end: endDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: foodType,
                                      predicate: predicate,
                                      limit: limit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: [["error": error.localizedDescription]])
                    return
                }

                let formatted: [[String: Any]] = (samples as? [HKCorrelation])?.compactMap { corr in
                    var calories = 0.0
                    var carbs = 0.0
                    var protein = 0.0
                    var fat = 0.0
                    // Try to infer a name from metadata or type
                    var name: String? = nil
                    if let nm = corr.metadata?[HKMetadataKeyFoodType] as? String { name = nm }

                    for obj in corr.objects {
                        if let q = obj as? HKQuantitySample {
                            let id = (q.quantityType as? HKQuantityType)?.identifier ?? "qty"
                            // Energy: prefer kilocalorie
                            if id.contains("Energy") || id.contains("dietaryEnergyConsumed") {
                                calories += q.quantity.doubleValue(for: HKUnit.kilocalorie())
                            } else if id.contains("Carbohydrates") {
                                carbs += q.quantity.doubleValue(for: HKUnit.gram())
                            } else if id.contains("Protein") {
                                protein += q.quantity.doubleValue(for: HKUnit.gram())
                            } else if id.contains("Fat") {
                                fat += q.quantity.doubleValue(for: HKUnit.gram())
                            } else {
                                // fallback: attempt common units
                                calories += q.quantity.doubleValue(for: HKUnit.kilocalorie())
                            }
                        }
                    }

                    let source = corr.sourceRevision.source.name
                    let bundle = corr.sourceRevision.source.bundleIdentifier ?? "-"

                    var metaOut: [String: Any] = [:]
                    if let meta = corr.metadata {
                        for (k, v) in meta {
                            metaOut[k] = v
                        }
                    }

                    return [
                        "timestamp": corr.startDate,
                        "name": name ?? "Food",
                        "caloriesKcal": calories,
                        "carbsGrams": carbs,
                        "proteinGrams": protein,
                        "fatGrams": fat,
                        "sourceName": source,
                        "sourceBundleId": bundle,
                        "metadata": metaOut
                    ]
                } ?? []

                continuation.resume(returning: formatted)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Local persistence helpers for standardized FoodItem model
    private let localFoodItemsKey = "hk_food_items_v1"

    /// Fetch recent food items and persist them locally as `FoodItem` JSON. Returns number saved.
    func saveFetchedFoodItemsToLocalStore(limit: Int = 50) async -> Int {
        let raw = await fetchRecentFoodItems(limit: limit)
        var items: [FoodItem] = []
        for dict in raw {
            if let err = dict["error"] as? String {
                continue
            }
            guard let ts = dict["timestamp"] as? Date else { continue }
            let name = dict["name"] as? String
            let calories = dict["caloriesKcal"] as? Double ?? 0
            let carbs = dict["carbsGrams"] as? Double ?? 0
            let protein = dict["proteinGrams"] as? Double ?? 0
            let fat = dict["fatGrams"] as? Double ?? 0
            let sourceName = dict["sourceName"] as? String
            let sourceBundle = dict["sourceBundleId"] as? String
            var metaCodable: [String: AnyCodable]? = nil
            if let meta = dict["metadata"] as? [String: Any] {
                var out: [String: AnyCodable] = [:]
                for (k, v) in meta {
                    out[k] = AnyCodable(v)
                }
                metaCodable = out
            }

            let fi = FoodItem(name: name,
                              timestamp: ts,
                              caloriesKcal: calories,
                              carbsGrams: carbs,
                              proteinGrams: protein,
                              fatGrams: fat,
                              sourceName: sourceName,
                              sourceBundleId: sourceBundle,
                              metadata: metaCodable)
            items.append(fi)
        }

        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: localFoodItemsKey)
            return items.count
        } catch {
            print("[HealthKitManager] Failed to encode food items: \(error)")
            return 0
        }
    }

    /// Return locally saved FoodItems (decoded), or empty array if none
    func getSavedFoodItems() -> [FoodItem] {
        guard let data = UserDefaults.standard.data(forKey: localFoodItemsKey) else { return [] }
        do {
            let items = try JSONDecoder().decode([FoodItem].self, from: data)
            return items
        } catch {
            print("[HealthKitManager] Failed to decode saved food items: \(error)")
            return []
        }
    }

    // MARK: - Workouts helpers (last 24 hours default)
    private let localWorkoutItemsKey = "hk_workout_items_v1"

    func fetchRecentWorkouts(limit: Int = 50, from startDate: Date? = nil, to endDate: Date = Date()) async -> [[String: Any]] {
        let fromDate = startDate ?? Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: fromDate, end: endDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: predicate, limit: limit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: [["error": error.localizedDescription]])
                    return
                }

                let out = (samples as? [HKWorkout])?.map { w in
                    return [
                        "startDate": w.startDate,
                        "endDate": w.endDate,
                        "durationMinutes": w.duration / 60.0,
                        "caloriesKcal": w.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0,
                        "type": w.workoutActivityType.name,
                        "sourceName": w.sourceRevision.source.name,
                        "sourceBundleId": w.sourceRevision.source.bundleIdentifier ?? "-"
                    ]
                } ?? []

                continuation.resume(returning: out)
            }
            healthStore.execute(query)
        }
    }

    func saveFetchedWorkoutsToLocalStore(limit: Int = 50) async -> Int {
        let raw = await fetchRecentWorkouts(limit: limit)
        var items: [WorkoutItem] = []
        for dict in raw {
            if let _ = dict["error"] as? String { continue }
            guard let start = dict["startDate"] as? Date,
                  let end = dict["endDate"] as? Date else { continue }
            let duration = dict["durationMinutes"] as? Double ?? 0
            let cal = dict["caloriesKcal"] as? Double ?? 0
            let type = dict["type"] as? String ?? "Workout"
            let source = dict["sourceName"] as? String
            let bundle = dict["sourceBundleId"] as? String
            let wi = WorkoutItem(type: type, startDate: start, endDate: end, durationMinutes: duration, caloriesKcal: cal, sourceName: source, sourceBundleId: bundle)
            items.append(wi)
        }

        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: localWorkoutItemsKey)
            return items.count
        } catch {
            print("[HealthKitManager] Failed to encode workout items: \(error)")
            return 0
        }
    }

    func getSavedWorkouts() -> [WorkoutItem] {
        guard let data = UserDefaults.standard.data(forKey: localWorkoutItemsKey) else { return [] }
        do {
            let items = try JSONDecoder().decode([WorkoutItem].self, from: data)
            return items
        } catch {
            print("[HealthKitManager] Failed to decode saved workout items: \(error)")
            return []
        }
    }
    
    func fetchGlucoseSampleCount() async throws -> Int {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return 0 }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: glucoseType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samplesOrNil, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let count = (samplesOrNil ?? []).count
                continuation.resume(returning: count)
            }
            healthStore.execute(query)
        }
    }
    
    func getAuthorizationRequestStatus() async -> String {
        // Return a concise summary used by the debug UI
        var parts: [String] = []
        if let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            let s = healthStore.authorizationStatus(for: glucoseType)
            parts.append("bloodGlucose:\(s)")
        }
        parts.append("readPermissionsGranted:\(readPermissionsGranted)")
        return parts.joined(separator: ", ")
    }
    
    private func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { throw HealthKitError.invalidType }
        // Do not gate on write-authorization; run the query and return 0 if no data.
        
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
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { throw HealthKitError.invalidType }
        // Do not gate on write-authorization; run the query and return 0 if no data.
        
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
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { throw HealthKitError.invalidType }
        // Do not gate on write-authorization; run the query and return 0 if no data.
        
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
        // Do not gate on write-authorization; perform the query and handle empty results.
        
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
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { throw HealthKitManagerError.dataFetchFailed }
        // Do not gate on write-authorization; perform the query and handle empty results.
        
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
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { throw HealthKitManagerError.dataFetchFailed }
        // Do not gate on write-authorization; perform the query and handle empty results.
        
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
        
        // Validate permission status
        let isAuthorized = validatePermissionStatus()
        if !isAuthorized {
#if DEBUG
            print("[HealthKitManager] Cannot fetch glucose samples: HealthKit permissions not granted")
#endif
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
    
    // MARK: - Observer & Anchored Query Helpers for incremental glucose updates
    private var glucoseObserverQuery: HKObserverQuery?
    private var glucoseAnchoredQuery: HKAnchoredObjectQuery?
    
    /// Start observing glucose samples and enable background delivery.
    /// Safe to call multiple times; will not register duplicates.
    func startGlucoseObserving() {
        guard HKHealthStore.isHealthDataAvailable() else {
#if DEBUG
            print("[HealthKitManager] Cannot start glucose observing: HealthKit not available")
#endif
            return
        }
        
        // If authorization hasn't been requested yet, proactively request it so the system shows the prompt.
        if authorizationStatus == .notDetermined {
            if showPermissionLogs {
                print("[HealthKitManager] Authorization not determined; requesting HealthKit permissions before observing")
            }
            requestHealthKitPermissions()
            // Do not proceed until the async permission callback runs — caller can call startObservingAndRefresh
            return
        }

        // Validate permission status first; if not authorized we won't start observing.
        let isAuthorized = validatePermissionStatus()
        if !isAuthorized {
#if DEBUG
            print("[HealthKitManager] Cannot start glucose observing: HealthKit permissions not granted")
#endif
            return
        }
        
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
#if DEBUG
            print("[HealthKitManager] Cannot start glucose observing: Blood glucose type not available")
#endif
            return
        }
        
        // Enable background delivery so the system can wake the app when new samples arrive.
        healthStore.enableBackgroundDelivery(for: glucoseType, frequency: .immediate) { success, error in
            if let error = error {
#if DEBUG
                print("enableBackgroundDelivery error: \(error.localizedDescription)")
#endif
            } else if success {
#if DEBUG
                print("Background delivery enabled for bloodGlucose")
#endif
            }
        }
        
        // Create an observer query to be notified when new glucose samples are written.
        if glucoseObserverQuery == nil {
            let query = HKObserverQuery(sampleType: glucoseType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
#if DEBUG
                    print("HKObserverQuery error: \(error.localizedDescription)")
#endif
                    completionHandler()
                    return
                }
                
                // When new samples arrive, run an anchored query to fetch only the new samples
                Task { [weak self] in
                    do {
                        await self?.fetchNewGlucoseSamplesViaAnchor(completion: {
                            completionHandler()
                        })
                    } catch {
#if DEBUG
                        print("[HealthKitManager] Error in glucose task: \(error.localizedDescription)")
#endif
                        completionHandler()
                    }
                }
            }
            
            glucoseObserverQuery = query
            healthStore.execute(query)
            activeQueries.append(query)
        }
    }
    
    func stopGlucoseObserving() {
        if let q = glucoseObserverQuery {
            healthStore.stop(q)
            glucoseObserverQuery = nil
        }
        if let aq = glucoseAnchoredQuery {
            healthStore.stop(aq)
            glucoseAnchoredQuery = nil
        }
    }
    
    private func loadSavedAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: glucoseAnchorKey) else { return nil }
        if let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            return anchor
        }
        return nil
    }
    
    private func saveAnchor(_ anchor: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: glucoseAnchorKey)
        }
    }
    
    /// Fetch new glucose samples using HKAnchoredObjectQuery and persist the new anchor.
    /// Calls completion after processing samples so observer completionHandler can be called.
    private func fetchNewGlucoseSamplesViaAnchor(completion: @escaping () -> Void = {}) async {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion()
            return
        }
        
        let anchor = loadSavedAnchor()
        let anchored = HKAnchoredObjectQuery(type: glucoseType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] _, addedOrNil, deletedOrNil, newAnchor, error in
            if let error = error {
#if DEBUG
                print("Anchored query error: \(error.localizedDescription)")
#endif
                completion()
                return
            }
            
            let added = (addedOrNil as? [HKQuantitySample]) ?? []
            if !added.isEmpty {
                // Process newest sample for quick UI update
                if let latest = added.max(by: { $0.startDate < $1.startDate }) {
                    let mgdl = latest.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
                    let sample = HealthKitGlucoseSample(value: mgdl, unit: "mg/dL", timestamp: latest.startDate)
                    Task { @MainActor in
                        self?.latestGlucoseSample = sample
                    }
                }
                
                // Optionally persist added samples into local DB / cache here
            }
            
            if let newAnchor = newAnchor {
                self?.saveAnchor(newAnchor)
            }
            
            completion()
        }
        
        // Store reference so we can stop it if needed
        glucoseAnchoredQuery = anchored
        healthStore.execute(anchored)
    }
    
    /// Public: force a refresh of recent glucose data from HealthKit and update published values.
    /// This will fetch recent samples (default last 6 hours), update `latestGlucoseSample`,
    /// and run the anchored query path to persist anchors so future observer callbacks behave correctly.
    /// A 15-minute cooldown is enforced between refreshes unless forceCooldownOverride is true.
    func refreshFromHealthKit(lastHours: Int = 6, forceCooldownOverride: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Check cooldown period (15 minutes) unless override is requested
        if !forceCooldownOverride {
            let now = Date()
            let lastRefreshDate = Date(timeIntervalSince1970: lastRefreshTimestamp)
            let cooldownPeriod: TimeInterval = 15 * 60 // 15 minutes in seconds
            
            if now.timeIntervalSince(lastRefreshDate) < cooldownPeriod {
                // Still on cooldown, update flag and exit
                await MainActor.run {
                    self.isRefreshOnCooldown = true
                    let remainingSeconds = Int(cooldownPeriod - now.timeIntervalSince(lastRefreshDate))
                    print("[HealthKitManager] Refresh on cooldown. \(remainingSeconds) seconds remaining.")
                }
                return
            }
        }
        
        // Reset cooldown flag
        await MainActor.run {
            self.isRefreshOnCooldown = false
        }
        
        // Validate permission status first to ensure we have the correct state
        let isAuthorized = validatePermissionStatus()
        
        // If we don't have read permission, do not attempt queries
        if !isAuthorized {
            if showPermissionLogs {
                print("[HealthKitManager] Cannot refresh: HealthKit permissions not granted")
            }
            return
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -lastHours, to: endDate) ?? Calendar.current.startOfDay(for: endDate)
        
        do {
            let samples = try await fetchGlucoseSamples(from: startDate, to: endDate)
            if let latest = samples.max(by: { $0.timestamp < $1.timestamp }) {
                self.latestGlucoseSample = latest
            }
            
            // Update timestamps for tracking refresh time and cooldown
            let now = Date()
            self.lastHealthKitRefresh = now
            self.lastRefreshTimestamp = now.timeIntervalSince1970
            
            // Debug log summary
#if DEBUG
            let count = samples.count
            if let latest = samples.max(by: { $0.timestamp < $1.timestamp }) {
                print("[HealthKitManager] refreshFromHealthKit: fetched \(count) samples, newest=\(latest.timestamp)")
            } else {
                print("[HealthKitManager] refreshFromHealthKit: fetched 0 samples")
            }
            if let anchorData = UserDefaults.standard.data(forKey: glucoseAnchorKey) {
                print("[HealthKitManager] anchor present (\(anchorData.count) bytes)")
            } else {
                print("[HealthKitManager] anchor: none")
            }
#endif
            
            // Also run anchored query path to pick up any missed samples and persist anchor
            await fetchNewGlucoseSamplesViaAnchor()
            
            // Notify WidgetKit timelines to reload so widgets can pick up the new data.
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
#if DEBUG
                print("[HealthKitManager] requested WidgetCenter.reloadAllTimelines()")
#endif
            }

            // Build combined payload and send to AI insights endpoint in one call
            Task { @MainActor in
                // Map glucose samples to APIManager model
                let apiGlucose: [APIManagerGlucoseReading] = samples.map { s in
                    let mgdl = s.value
                    return APIManagerGlucoseReading(value: Int(round(mgdl)), trend: "unknown", timestamp: s.timestamp, unit: s.unit)
                }

                // Map workouts from local store
                let savedWorkouts = self.getSavedWorkouts()
                let apiWorkouts: [APIManagerWorkoutData] = savedWorkouts.map { w in
                    return APIManagerWorkoutData(type: w.type, duration: w.durationMinutes * 60.0, calories: w.caloriesKcal, startDate: w.startDate, endDate: w.endDate)
                }

                // Map food items from local store
                let savedFoods = self.getSavedFoodItems()
                let apiFoods: [APIManagerNutritionData] = savedFoods.map { f in
                    return APIManagerNutritionData(name: f.name ?? "Food", calories: f.caloriesKcal, carbs: f.carbsGrams, protein: f.proteinGrams, fat: f.fatGrams, timestamp: f.timestamp)
                }

                // Build APIManagerHealthData
                let apiHealthData = APIManagerHealthData(glucose: apiGlucose, workouts: apiWorkouts, nutrition: apiFoods, timestamp: Date())

                // Gather cached items from CacheManager
                let cached = CacheManager.shared.getItems(since: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

                // Send to API
                let api = APIManager()
                do {
                    let insights = try await api.uploadCacheAndGenerateInsights(healthData: apiHealthData, cachedItems: cached, prompt: nil)
#if DEBUG
                    print("[HealthKitManager] uploadCacheAndGenerateInsights returned \(insights.count) insights")
#endif
                    // Write insights back to HealthKit as a pseudodatabase
                    await saveInsightsToHealthKit(insights: insights)
                } catch {
#if DEBUG
                    print("[HealthKitManager] uploadCacheAndGenerateInsights failed: \(error.localizedDescription)")
#endif
                }
            }
        } catch {
#if DEBUG
            print("[HealthKitManager] refreshFromHealthKit failed: \(error.localizedDescription)")
#endif
        }
    }
    
    /// Persist insights locally as a fallback. Some HealthKit clinical APIs are not available
    /// across all SDK versions; storing locally avoids using unavailable types while preserving
    /// the idea of a pseudodatabase for later sync/inspection.
    private func saveInsightsToHealthKit(insights: [AIInsight]) async {
        guard !insights.isEmpty else { return }
        // Try to write to HealthKit using a mindfulSession category sample if write permission exists
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            let status = healthStore.authorizationStatus(for: mindfulType)
            if status == .sharingAuthorized {
                // Prepare JSON metadata
                guard let data = try? JSONEncoder().encode(insights), let json = String(data: data, encoding: .utf8) else {
                    print("[HealthKitManager] Failed to encode insights for HealthKit storage")
                    return
                }

                // Use mindfulSession start/end same timestamp; duration zero. Store JSON in metadata.
                let now = Date()
                let metadata: [String: Any] = [
                    "glucopilot.insights": json,
                    "glucopilot.insight_count": insights.count,
                    HKMetadataKeyWasUserEntered: true
                ]

                let sample = HKCategorySample(type: mindfulType, value: 0, start: now, end: now, metadata: metadata)

                do {
                    try await healthStore.save(sample)
                    print("[HealthKitManager] Saved \(insights.count) insights to Health app via mindfulSession sample")
                    return
                } catch {
                    print("[HealthKitManager] Failed to save insights to HealthKit: \(error.localizedDescription)")
                    // Fall through to local persistence
                }
            }
        }

        // Fallback: Encode insights to JSON and persist in UserDefaults
        do {
            let data = try JSONEncoder().encode(insights)
            UserDefaults.standard.setValue(data, forKey: "glucopilot.saved_insights")
            UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: "glucopilot.saved_insights_ts")
            print("[HealthKitManager] Persisted \(insights.count) insights to UserDefaults (pseudodatabase)")
        } catch {
            print("[HealthKitManager] Failed to persist insights locally: \(error.localizedDescription)")
        }
    }
    
    /// Convenience helper to start observing glucose samples and immediately trigger a refresh.
    /// Safe to call repeatedly.
    func startObservingAndRefresh(lastHours: Int = 6) {
        startGlucoseObserving()
        Task {
            await refreshFromHealthKit(lastHours: lastHours)
        }
    }
    
    /// Stops all HealthKit observations and queries
    func stopObservingHealthData() {
        // First stop glucose-specific observers
        stopGlucoseObserving()
        
        // Stop any other active queries
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
        
        // Log the action
#if DEBUG
        print("[HealthKitManager] Stopped all health data observations")
#endif
    }

    /// Reset all HealthKit-related state for this app instance.
    /// - Note: This does not revoke system permissions (users manage that in the Health app),
    ///         but it clears local flags, anchors, observers, and published values.
    func resetAllHealthKitState() {
        // Stop any ongoing observations/queries
        stopObservingHealthData()

        // Attempt to disable background delivery entirely (best-effort)
        healthStore.disableAllBackgroundDelivery { success, error in
            #if DEBUG
            if let error = error {
                print("[HealthKitManager] disableAllBackgroundDelivery error: \(error.localizedDescription)")
            } else {
                print("[HealthKitManager] disableAllBackgroundDelivery success=\(success)")
            }
            #endif
        }

        // Clear saved anchors so next observe starts fresh
        UserDefaults.standard.removeObject(forKey: glucoseAnchorKey)

        // Reset internal authorization/read flags (local only)
        hasLoggedAuthorizationGranted = false
        readPermissionsGranted = false
        readPermissionsGrantedStored = false
        authorizationStatus = .notDetermined

        // Clear published values used by UI
        todaySteps = 0
        activeMinutes = 0
        sleepHours = 0
        averageHeartRate = 0
        latestGlucoseSample = nil
        lastHealthKitRefresh = nil

        #if DEBUG
        print("[HealthKitManager] resetAllHealthKitState: local state cleared")
        #endif
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
