import SwiftUI
import UIKit

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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.horizontal)

            Button(action: skip) {
                Text("Skip for now")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)

            if let result = requestResult, result.contains("not granted") {
                Button(action: openSettings) {
                    Text("Open Settings")
                }
            }

            Spacer()
        }
        .padding()
    }

    private func requestPermissions() {
        isRequesting = true
        requestResult = nil

        // Request permissions and then update result
        Task {
            await MainActor.run {
                healthKitManager.requestHealthKitPermissions()
            }

            // Wait briefly for authorization status to update
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                isRequesting = false
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    requestResult = "Permissions granted — syncing data..."
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
