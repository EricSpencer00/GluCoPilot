import SwiftUI
import UIKit
import HealthKit

struct HealthKitSetupView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isRequesting = false
    @State private var requestResult: String? = nil
    let onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red.gradient)

            Text("Connect Apple Health")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("To provide personalized insights we need permission to read your health data (steps, heart rate, sleep, and blood glucose). This data stays on your device and is only shared with your permission.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if let result = requestResult {
                Text(result)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: requestPermissions) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isRequesting ? "Requesting…" : "Connect Apple Health")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle(colors: [Color.red, Color.pink]))
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.horizontal)
            
            // Add a direct request button as a fallback
            Button(action: {
                let healthStore = HKHealthStore()
                let allTypes = Set([
                    HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
                    HKObjectType.quantityType(forIdentifier: .stepCount)!,
                    HKObjectType.quantityType(forIdentifier: .heartRate)!
                ])
                
                print("Requesting direct permission with minimal types")
                
                healthStore.requestAuthorization(toShare: nil, read: allTypes) { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Direct permission error: \(error)")
                        }
                        print("Direct permission result: \(success)")
                        
                        if success {
                            self.requestResult = "Permissions granted via direct request"
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            self.healthKitManager.shouldInitializeHealthKit = true
                            self.healthKitManager.authorizationStatus = .sharingAuthorized
                            self.onComplete?()
                        }
                    }
                }
            }) {
                Text("Try Direct Permission Request")
                    .foregroundColor(.blue)
                    .padding(.top, 8)
            }

            // If the auth flow requires HealthKit, do not allow skipping.
            if authManager.requiresHealthKitAuthorization {
                Text("Health data permission is required to continue.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Button(action: skip) {
                    Text("Skip for now")
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }

            if let result = requestResult, result.contains("not granted") {
                VStack(spacing: 10) {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        // Open Health app directly
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }) {
                        Text("Open Health App")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        // Open app's Privacy settings directly
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }) {
                        Text("Open App Privacy Settings")
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()
        }
        .padding()
    .withTopGradient()
    }

    private func requestPermissions() {
        isRequesting = true
        requestResult = nil
        
        print("HealthKitSetupView: Starting permission request")
        
        // Use the direct request method
        healthKitManager.directRequestPermission { [weak self] success in
            guard let self = self else { return }
            
            self.isRequesting = false
            
            if success {
                self.requestResult = "Permissions granted \u{2014} syncing data..."
                // Mark that user has completed setup
                UserDefaults.standard.set(false, forKey: "hasSkippedHealthKitSetup")
                UserDefaults.standard.set(true, forKey: "hasAcknowledgedLimitedFunctionality")
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                // Set the manager state
                self.healthKitManager.shouldInitializeHealthKit = true
                self.healthKitManager.authorizationStatus = .sharingAuthorized
                
                // Fetch initial properties
                Task {
                    await self.healthKitManager.updatePublishedProperties()
                    self.onComplete?()
                }
            } else {
                self.requestResult = "Permissions not granted. You can enable them in Settings to access full features."
            }
        }

            // Poll briefly for change in authorization status (HealthKit callbacks can be async)
            var attempts = 0
            while attempts < 6 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                attempts += 1
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    break
                }
            }

            await MainActor.run {
                isRequesting = false
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    requestResult = "Permissions granted \u{2014} syncing data..."
                    // Mark that user has completed setup
                    UserDefaults.standard.set(false, forKey: "hasSkippedHealthKitSetup")
                    UserDefaults.standard.set(true, forKey: "hasAcknowledgedLimitedFunctionality")
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    healthKitManager.shouldInitializeHealthKit = true
                    // Fetch initial properties
                    Task {
                        await healthKitManager.updatePublishedProperties()
                        onComplete?()
                    }
                } else {
                    requestResult = "Permissions not granted. You can enable them in Settings to access full features."
                }
            }
        }
    }

    private func skip() {
        // Pass back to ContentView that user skipped HealthKit
        UserDefaults.standard.set(true, forKey: "hasSkippedHealthKitSetup")
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete?()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }


#Preview {
    HealthKitSetupView()
}
