import SwiftUI
import UIKit

struct HealthKitSetupView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var appState: AppState
    
    @State private var currentStep: SetupStep = .introduction
    @State private var isRequesting = false
    @State private var requestResult: String? = nil
    
    let onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    enum SetupStep {
        case introduction
        case requestPermission
        case result
    }

    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(getStepColor(for: index))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top)
            
            Spacer()
            
            // Different content based on current step
            Group {
                switch currentStep {
                case .introduction:
                    introductionView
                case .requestPermission:
                    permissionRequestView
                case .result:
                    resultView
                }
            }
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding()
        .withTopGradient()
        .accessibilityElement(children: .contain)
    }
    
    private var introductionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red.gradient)
                .accessibilityHidden(true)
            
            Text("Connect Apple Health")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("GluCoPilot uses your health data to provide personalized insights and recommendations.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "chart.xyaxis.line", title: "Track glucose trends", description: "See patterns in your blood glucose levels")
                benefitRow(icon: "figure.walk", title: "Activity insights", description: "Understand how exercise affects your glucose")
                benefitRow(icon: "fork.knife", title: "Nutrition impact", description: "Learn how food choices affect your levels")
                benefitRow(icon: "bed.double.fill", title: "Sleep analysis", description: "See how sleep quality influences glucose")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Your data stays on your device and is only shared with your permission. We never sell your data.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
                .accessibilityHidden(true)
            
            Text("Allow Health Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("GluCoPilot needs permission to read:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(icon: "drop.fill", title: "Blood Glucose", color: .red)
                permissionRow(icon: "figure.walk", title: "Steps & Activity", color: .green)
                permissionRow(icon: "heart.fill", title: "Heart Rate", color: .pink)
                permissionRow(icon: "bed.double.fill", title: "Sleep", color: .indigo)
                permissionRow(icon: "fork.knife", title: "Nutrition", color: .orange)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Apple will ask for your permission in the next step.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var resultView: some View {
        VStack(spacing: 20) {
            if healthKitManager.authorizationStatus == .sharingAuthorized {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)
                
                Text("Connected Successfully")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your health data is now connected. GluCoPilot will provide personalized insights based on your data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let result = requestResult {
                    Text(result)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Failed state
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.orange)
                
                Text("Permission Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Health permissions were not granted. Some features may be limited.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: openSettings) {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.top)
                .accessibilityHint("Opens the Settings app where you can enable health permissions")
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .introduction:
                Button(action: { currentStep = .requestPermission }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(colors: [Color.blue, Color.purple]))
                .controlSize(.large)
                .padding(.horizontal)
                .accessibilityHint("Continue to permission request screen")
                
                // Skip button only if not required by auth flow
                if !authManager.requiresHealthKitAuthorization {
                    Button(action: skip) {
                        Text("Skip for now")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityHint("Skip the health setup process")
                }
                
            case .requestPermission:
                Button(action: requestPermissions) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isRequesting ? "Requesting…" : "Allow Health Access")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(colors: [Color.blue, Color.green]))
                .controlSize(.large)
                .disabled(isRequesting)
                .padding(.horizontal)
                .accessibilityHint("Request access to health data")
                
                Button(action: { currentStep = .introduction }) {
                    Text("Back")
                        .foregroundColor(.secondary)
                }
                .disabled(isRequesting)
                .accessibilityHint("Go back to introduction screen")
                
            case .result:
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    Button(action: skip) {
                        Text("Continue to App")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle(colors: [Color.green, Color.blue]))
                    .controlSize(.large)
                    .padding(.horizontal)
                    .accessibilityHint("Complete setup and go to the main app")
                } else if !authManager.requiresHealthKitAuthorization {
                    // Only show skip if permissions aren't required
                    Button(action: skip) {
                        Text("Continue without Health Data")
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                    .accessibilityHint("Skip health permissions and continue to app with limited functionality")
                }
            }
        }
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private func permissionRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
    
    private func getStepColor(for index: Int) -> Color {
        let currentIndex: Int
        
        switch currentStep {
        case .introduction: currentIndex = 0
        case .requestPermission: currentIndex = 1
        case .result: currentIndex = 2
        }
        
        if index < currentIndex {
            return .blue // Completed steps
        } else if index == currentIndex {
            return .blue.opacity(0.8) // Current step
        } else {
            return .gray.opacity(0.3) // Future steps
        }
    }

    private func requestPermissions() {
        isRequesting = true
        requestResult = nil

        // Request permissions and then update result
        Task {
            // Trigger request on the HealthKit manager
            await MainActor.run {
                healthKitManager.requestHealthKitPermissions()
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
                currentStep = .result
                
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    requestResult = "Permissions granted \u{2014} syncing data..."
                    // Fetch initial properties
                    Task {
                        await healthKitManager.updatePublishedProperties()
                    }
                } else {
                    requestResult = "Permissions not granted. You can enable them in Settings."
                }
            }
        }
    }

    private func skip() {
        Logger.info("User skipped HealthKit setup or completed it successfully")
        onComplete?()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// Maintain the existing GradientButtonStyle or create if missing
struct GradientButtonStyle: ButtonStyle {
    var colors: [Color]
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

#Preview {
    HealthKitSetupView()
        .environmentObject(HealthKitManager())
        .environmentObject(AuthenticationManager())
        .environmentObject(AppState())
}
