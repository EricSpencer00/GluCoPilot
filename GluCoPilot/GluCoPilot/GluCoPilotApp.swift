import SwiftUI
import AuthenticationServices
import HealthKit

@main
struct GluCoPilotApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var apiManager = APIManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthManager)
                .environmentObject(apiManager)
                .withGlobalTopGradient()
                .onAppear {
                    // For now, request HealthKit permissions immediately on first UI appearance.
                    // This is a temporary measure to ensure the permission prompt is shown reliably
                    // before we start observation. We may move this into an onboarding flow later.

                    // Detailed runtime diagnostics to help debug HealthKit permission problems
                    let bundle = Bundle.main
                    print("[App] bundleIdentifier: \(bundle.bundleIdentifier ?? "<none>")")
                    print("[App] bundleExecutable: \(bundle.executableURL?.lastPathComponent ?? "<none>")")
                    print("[App] CFBundleDisplayName: \(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "<none>")")
                    print("[App] CFBundleShortVersionString: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "<none>")")
                    print("[App] CFBundleVersion: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "<none>")")

                    print("[App] healthKitAvailable: \(HKHealthStore.isHealthDataAvailable())")

                    if let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
                        let status = HKHealthStore().authorizationStatus(for: glucoseType)
                        print("[App] HK authStatus(bloodGlucose) = \(status.rawValue) (\(status))")
                    } else {
                        print("[App] HK bloodGlucose type unavailable")
                    }

                    // Check for embedded provisioning profile in the app bundle (useful for diagnosing signing/profile issues)
                    if let provPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: provPath),
                           let size = attrs[.size] as? NSNumber {
                            print("[App] embedded.mobileprovision found at: \(provPath) size: \(size.intValue) bytes")
                        } else {
                            print("[App] embedded.mobileprovision found at: \(provPath)")
                        }
                    } else {
                        print("[App] No embedded.mobileprovision in bundle (normal for App Store / TestFlight builds)")
                    }

                    // Trigger the in-app permission request asynchronously on the main queue to avoid UI timing issues
                    DispatchQueue.main.async {
                        healthManager.requestHealthKitPermissions()
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    let refreshed = await authManager.refreshAppleIDTokenIfNeeded()
                    if refreshed {
                        print("[App] Apple id_token refreshed on becoming active")
                    }
                    // Ensure HealthKit permissions are requested (if not determined) and start observation/refresh.
                    // Requesting permissions before starting observations avoids the "permissions not granted" race.
                    if healthManager.authorizationStatus == .notDetermined {
                        healthManager.requestHealthKitPermissions()
                    }

                    // Start observing and proactively refresh recent glucose samples. If permissions are
                    // not yet granted this call will be a no-op; when/if the user grants permissions the
                    // `requestHealthKitPermissions` completion path will call `startGlucoseObserving()`.
                    healthManager.startObservingAndRefresh()
                }
            }
        }
    }
}
