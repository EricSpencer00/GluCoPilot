import SwiftUI
import AuthenticationServices

struct AppleSignInDebugView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var testResult: String = ""
    @State private var isLoading = false
    @State private var currentToken: String?
    
    var body: some View {
        List {
            Section("Current Status") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("User ID:")
                        .font(.headline)
                    Text(KeychainHelper().getValue(for: "apple_user_id") ?? "None")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("ID Token Status:")
                        .font(.headline)
                    if let token = KeychainHelper().getValue(for: "apple_id_token") {
                        Text("Present: \(String(token.prefix(15)))...")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Text("Missing")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Actions") {
                Button {
                    isLoading = true
                    Task {
                        testResult = await authManager.testAppleSignIn()
                        isLoading = false
                    }
                } label: {
                    HStack {
                        Text("Test Apple Sign In")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
                
                Button(role: .destructive) {
                    let keychain = KeychainHelper()
                    keychain.removeValue(for: "apple_id_token")
                    currentToken = nil
                    testResult = "Token removed from keychain"
                } label: {
                    Text("Clear ID Token")
                }
            }
            
            if !testResult.isEmpty {
                Section("Test Results") {
                    Text(testResult)
                        .font(.callout)
                        .foregroundStyle(testResult.contains("Error") ? .red : .primary)
                }
            }
            
            Section("Troubleshooting") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Common Issues:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Make sure app has correct entitlements")
                        Text("• Sign In with Apple capability must be enabled")
                        Text("• On simulator, fallback tokens are used")
                        Text("• Real device works best for Apple Sign In")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Apple Sign In Debug")
        .onAppear {
            currentToken = KeychainHelper().getValue(for: "apple_id_token")
        }
    }
}

#Preview {
    NavigationStack {
        AppleSignInDebugView()
            .environmentObject(AuthenticationManager())
    }
}
