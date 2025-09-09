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
        
        // Reset any cached permissions state when the view is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let manager = HealthKitManager()
            manager.resetAllHealthKitState()
        }
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
                // Create a completely new HKHealthStore instance
                let healthStore = HKHealthStore()
                
                // Start with a single type for initial request
                let singleType = Set([
                    HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
                ])
                
                print("Requesting direct inline permission with SINGLE type")
                self.isRequesting = true
                self.requestResult = "Requesting permission..."
                
                // Set a timeout for this direct request
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    guard isRequesting else { return }

                    // If we're still requesting after 15 seconds, show a message
                    isRequesting = false
                    requestResult = "Direct request timed out. Please try again or open Health app settings."
                }
                
                // First, request a single type to maximize chance of prompt appearing
                healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: singleType) { success, error in
                    print("First direct inline permission result: \(success), error: \(String(describing: error))")
                    
                    // Now try with multiple types as a fallback
                    let allTypes = Set([
                        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
                        HKObjectType.quantityType(forIdentifier: .stepCount)!,
                        HKObjectType.quantityType(forIdentifier: .heartRate)!
                    ])
                    
                    // Create a fresh store for the second request
                    let secondStore = HKHealthStore()
                    
                    print("Trying second direct inline permission with MULTIPLE types")
                    
                    secondStore.requestAuthorization(toShare: Set<HKSampleType>(), read: allTypes) { secondSuccess, secondError in
                        DispatchQueue.main.async {
                            self.isRequesting = false
                            
                            print("Second direct inline permission result: \(secondSuccess), error: \(String(describing: secondError))")
                            
                            // Use the best result we got
                            let finalSuccess = success || secondSuccess
                            
                            if finalSuccess {
                                self.requestResult = "Permissions granted via direct request"
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                                self.healthKitManager.shouldInitializeHealthKit = true
                                self.healthKitManager.authorizationStatus = .sharingAuthorized
                                // Use the helper method to call onComplete correctly
                                self.updateProperties()
                            } else {
                                if let error = error ?? secondError {
                                    self.requestResult = "Error: \(error.localizedDescription)"
                                } else {
                                    self.requestResult = "Direct request: Permissions not granted"
                                }
                            }
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
        
        // Set a timeout to update UI if the request hangs
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            guard isRequesting else { return }

            // If we're still requesting after 15 seconds, show a message
            isRequesting = false
            requestResult = "Request timed out. Please try again or use the direct request button below."
        }
        
        // Clear all cached permissions to ensure prompt shows
        UserDefaults.standard.removeObject(forKey: "hk_read_permissions_granted")
        
        // Try a direct approach first with our own HKHealthStore
        let directStore = HKHealthStore()
        let singleType = Set([HKObjectType.quantityType(forIdentifier: .bloodGlucose)!])
        
        print("HealthKitSetupView: Trying direct single-type request first")
        
        directStore.requestAuthorization(toShare: Set<HKSampleType>(), read: singleType) { [self] firstSuccess, firstError in
            print("HealthKitSetupView: First direct request result: \(firstSuccess), error: \(String(describing: firstError))")
            
            // If that worked, great! If not, try the manager approach
            if firstSuccess {
                DispatchQueue.main.async {
                    self.isRequesting = false
                    self.requestResult = "Permissions granted \u{2014} syncing data..."
                    // Mark that user has completed setup
                    UserDefaults.standard.set(false, forKey: "hasSkippedHealthKitSetup")
                    UserDefaults.standard.set(true, forKey: "hasAcknowledgedLimitedFunctionality")
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    
                    // Set the manager state
                    self.healthKitManager.shouldInitializeHealthKit = true
                    self.healthKitManager.authorizationStatus = .sharingAuthorized
                    
                    // Fetch initial properties
                    self.updateProperties()
                }
            } else {
                // Try the manager's method as a fallback
                print("HealthKitSetupView: First attempt failed, trying manager method")
                
                // Use the direct request method from the manager
                healthKitManager.directRequestPermission { success in
                    DispatchQueue.main.async {
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
                            self.updateProperties()
                        } else {
                            self.requestResult = "Permissions not granted. You can enable them in Settings to access full features."
                        }
                    }
                }
            }
        }
    }
    
    private func updateProperties() {
        // Create a task to handle the async work
        Task { 
            await healthKitManager.updatePublishedProperties()
            DispatchQueue.main.async {
                self.onComplete?()
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

}


#Preview {
    HealthKitSetupView()
}
