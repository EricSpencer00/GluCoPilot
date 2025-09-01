import SwiftUI
import AuthenticationServices

struct AppleSignInDebugView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var testResult: String = ""
    @State private var isLoading = false
    @State private var currentToken: String?
    @State private var tokenHeader: String = ""
    @State private var tokenClaims: String = ""
    
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
                    tokenHeader = ""
                    tokenClaims = ""
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

            if let token = currentToken {
                Section("Token (decoded)") {
                    if !tokenHeader.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Header:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(tokenHeader)
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                    }
                    if !tokenClaims.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Claims:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(tokenClaims)
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                    }
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
            if let token = currentToken {
                let (h, c) = decodeJWTParts(token)
                tokenHeader = h
                tokenClaims = c
            }
        }
    }
}

// MARK: - JWT helpers (debug only)
fileprivate func decodeJWTParts(_ token: String) -> (String, String) {
    let parts = token.split(separator: ".")
    guard parts.count >= 2 else { return ("", "") }

    func decodeBase64URL(_ s: Substring) -> String {
        var str = String(s)
        // Add padding
        let rem = str.count % 4
        if rem > 0 {
            str += String(repeating: "=", count: 4 - rem)
        }
        str = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if let data = Data(base64Encoded: str), let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
        return ""
    }

    let header = decodeBase64URL(parts[0])
    let claims = decodeBase64URL(parts[1])
    return (header, claims)
}

#Preview {
    NavigationStack {
        AppleSignInDebugView()
            .environmentObject(AuthenticationManager())
    }
}
