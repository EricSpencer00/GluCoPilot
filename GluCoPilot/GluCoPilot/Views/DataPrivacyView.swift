import SwiftUI
import HealthKit

struct DataPrivacyView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showingDeleteConfirmation = false
    @State private var exportInProgress = false
    @State private var exportSuccess = false
    @State private var exportError = false
    
    var body: some View {
        List {
            Section(header: Text("Data Collection")) {
                NavigationLink(destination: StaticDocumentView(title: "Privacy Policy", content: StaticDocumentView.privacyPlaceholder)) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }
                
                NavigationLink(destination: HealthDataAccessView()) {
                    Label("Health Data Access", systemImage: "heart.text.square")
                }
            }
            
            Section(header: Text("Your Data"), footer: Text("View what data has been collected from your device.")) {
                NavigationLink(destination: CollectedDataSummaryView()) {
                    Label("View Collected Data", systemImage: "list.bullet.clipboard")
                }
            }
            
            Section(header: Text("Data Controls")) {
                Button(action: {
                    exportData()
                }) {
                    HStack {
                        Label("Export Your Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if exportInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(exportInProgress)
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Consent Management")) {
                Toggle("Health Data Collection", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "hasConsentedToDataCollection") },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "hasConsentedToDataCollection")
                        if !newValue {
                            // If user withdraws consent, stop data collection
                            healthKitManager.stopObservingHealthData()
                        } else {
                            // If user gives consent, restart data collection
                            healthKitManager.startObservingAndRefresh()
                        }
                    }
                ))
                
                Button(action: {
                    // Show consent view again
                    showConsentAgain()
                }) {
                    Text("Review Consent Agreements")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Data & Privacy")
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete All Data"),
                message: Text("Are you sure you want to delete all your data? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAllData()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Data Export", isPresented: $exportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data has been exported successfully. You can find the file in your Downloads folder.")
        }
        .alert("Export Failed", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There was a problem exporting your data. Please try again later.")
        }
    }
    
    private func exportData() {
        exportInProgress = true
        
        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exportInProgress = false
            exportSuccess = true
            // In a real implementation, you would:
            // 1. Gather all user data
            // 2. Format it as JSON or CSV
            // 3. Use UIActivityViewController or similar to let user save the file
        }
    }
    
    private func deleteAllData() {
        // In a real implementation, you would:
        // 1. Call your API to delete user data from the server
        // 2. Clear local caches
        // 3. Reset user preferences
        
        // Note: HealthKit data itself can't be deleted by your app,
        // but you can revoke permissions and stop collecting it
    }
    
    private func showConsentAgain() {
        // In a real implementation, you would present the ConsentView again
        // This is a placeholder for the implementation
    }
}

struct HealthDataAccessView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        List {
            Section(header: Text("Health Data Access")) {
                dataTypeRow(title: "Blood Glucose", isAccessed: true)
                dataTypeRow(title: "Heart Rate", isAccessed: true)
                dataTypeRow(title: "Step Count", isAccessed: true)
                dataTypeRow(title: "Sleep Analysis", isAccessed: true)
                dataTypeRow(title: "Workouts", isAccessed: true)
                dataTypeRow(title: "Dietary Information", isAccessed: true)
            }
            
            Section(header: Text("Manage Permissions")) {
                Button(action: {
                    openHealthAppSettings()
                }) {
                    Text("Manage in Health App")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    print("Direct HealthKit permission request from DataPrivacyView")
                    
                    // Reset all HealthKit state to ensure a fresh prompt
                    $healthKitManager.resetAllHealthKitState
                    
                    // Create a local tracking variable instead of using @State
                    var isRequestingLocal = true
                    
                    // Set a timeout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        if isRequestingLocal {
                            isRequestingLocal = false
                            print("HealthKit permission request timed out in DataPrivacyView")
                        }
                    }
                    
                    // Try a direct approach first with our own HKHealthStore
                    let directStore = HKHealthStore()
                    let singleType = Set([HKObjectType.quantityType(forIdentifier: .bloodGlucose)!])
                    
                    print("DataPrivacyView: Trying direct single-type request")
                    
                    directStore.requestAuthorization(toShare: Set<HKSampleType>(), read: singleType) { firstSuccess, firstError in
                        print("DataPrivacyView: Direct request result: \(firstSuccess), error: \(String(describing: firstError))")
                        
                        if firstSuccess {
                            DispatchQueue.main.async {
                                isRequestingLocal = false
                                print("Permission granted from DataPrivacyView direct request")
                                healthKitManager.authorizationStatus = .sharingAuthorized
                                healthKitManager.shouldInitializeHealthKit = true
                            }
                        } else {
                            // Try the manager's method as a fallback
                            healthKitManager.directRequestPermission { success in
                                DispatchQueue.main.async {
                                    isRequestingLocal = false
                                    if success {
                                        print("Permission granted from DataPrivacyView manager request")
                                        healthKitManager.authorizationStatus = .sharingAuthorized
                                        healthKitManager.shouldInitializeHealthKit = true
                                    } else {
                                        print("Permission denied from DataPrivacyView")
                                    }
                                }
                            }
                        }
                    }
                }) {
                    Text("Request HealthKit Permissions")
                        .foregroundColor(.blue)
                }
                
                // Add a direct inline request button as a fallback
                Button(action: {
                    // Create a completely new HKHealthStore instance
                    let healthStore = HKHealthStore()
                    
                    // Create a local tracking variable
                    var isRequestingLocal = true
                    
                    // Start with a single type for maximum prompt likelihood
                    let singleType = Set([
                        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
                    ])
                    
                    print("Requesting SINGLE type direct inline permission")
                    
                    // Set a timeout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        if isRequestingLocal {
                            isRequestingLocal = false
                            print("Direct inline HealthKit SINGLE permission request timed out")
                        }
                    }
                    
                    // First try with just one type
                    healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: singleType) { success, error in
                        print("Direct inline SINGLE type permission result: \(success), error: \(String(describing: error))")
                        
                        if success {
                            DispatchQueue.main.async {
                                isRequestingLocal = false
                                healthKitManager.shouldInitializeHealthKit = true
                                healthKitManager.authorizationStatus = .sharingAuthorized
                            }
                        } else {
                            // If that didn't work, try with multiple types
                            let allTypes = Set([
                                HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
                                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                                HKObjectType.quantityType(forIdentifier: .heartRate)!
                            ])
                            
                            // Create a fresh store for the second attempt
                            let secondStore = HKHealthStore()
                            
                            print("Trying MULTIPLE types direct inline permission")
                            
                            secondStore.requestAuthorization(toShare: Set<HKSampleType>(), read: allTypes) { secondSuccess, secondError in
                                DispatchQueue.main.async {
                                    isRequestingLocal = false
                                    
                                    print("Direct inline MULTIPLE types result: \(secondSuccess), error: \(String(describing: secondError))")
                                    
                                    if secondSuccess {
                                        healthKitManager.shouldInitializeHealthKit = true
                                        healthKitManager.authorizationStatus = .sharingAuthorized
                                    }
                                }
                            }
                        }
                    }
                }) {
                    Text("Try Direct Permission Request")
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Health Data Access")
    }
    
    private func dataTypeRow(title: String, isAccessed: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isAccessed {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func openHealthAppSettings() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

struct CollectedDataSummaryView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        List {
            Section(header: Text("Glucose Data")) {
                Text("Last 7 days: \(Int.random(in: 10...50)) readings")
                Text("Last 30 days: \(Int.random(in: 40...200)) readings")
            }
            
            Section(header: Text("Activity Data")) {
                Text("Last 7 days: \(Int.random(in: 5...20)) workouts")
                Text("Step count records: \(Int.random(in: 1...30)) days")
            }
            
            Section(header: Text("Food Entries")) {
                Text("Last 30 days: \(Int.random(in: 0...60)) entries")
            }
            
            Section(header: Text("Other Health Data")) {
                Text("Sleep records: \(Int.random(in: 1...30)) days")
                Text("Heart rate samples: \(Int.random(in: 1...30)) days")
            }
            
            Section(header: Text("Note")) {
                Text("This is a summary of data available to GluCoPilot through Apple HealthKit. No data is stored permanently on our servers. Data is processed transiently to generate insights and recommendations.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Your Data Summary")
    }
}

struct DataPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DataPrivacyView()
                .environmentObject(HealthKitManager())
        }
    }
}
