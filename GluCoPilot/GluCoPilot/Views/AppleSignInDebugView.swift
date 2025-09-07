import SwiftUI
import AuthenticationServices

struct AppleSignInDebugView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var testResult: String = ""
    @State private var isLoading = false
    @State private var currentToken: String?
    @State private var tokenHeader: String = ""
    @State private var tokenClaims: String = ""
    @State private var manualToken: String = ""
    @State private var backendExchangeResult: String = ""
    @State private var showClaims: Bool = false
    
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
                        HStack {
                            Text("Present: \(String(token.prefix(15)))...")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            if let exp = getTokenExpiry(token) {
                                if exp.timeIntervalSinceNow > 0 {
                                    Text("Valid")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                } else {
                                    Text("Expired")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    } else {
                        Text("Missing")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend Access Token:")
                        .font(.headline)
                    if let token = KeychainHelper().getValue(for: "auth_access_token") {
                        HStack {
                            Text("Present: \(String(token.prefix(15)))...")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            if let exp = getTokenExpiry(token) {
                                if exp.timeIntervalSinceNow > 0 {
                                    Text("Valid (\(Int(exp.timeIntervalSinceNow / 60)) min)")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                } else {
                                    Text("Expired")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    } else {
                        Text("Missing")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend Refresh Token:")
                        .font(.headline)
                    if let token = KeychainHelper().getValue(for: "auth_refresh_token") {
                        HStack {
                            Text("Present: \(String(token.prefix(15)))...")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            if let exp = getTokenExpiry(token) {
                                if exp.timeIntervalSinceNow > 0 {
                                    Text("Valid (\(Int(exp.timeIntervalSinceNow / 3600)) hours)")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                } else {
                                    Text("Expired")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                        }
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
                
                Button {
                    isLoading = true
                    Task {
                        // New: attempt to ensure a backend token silently and display result
                        if let api = authManager.apiManager {
                            #if DEBUG
                            do {
                                let token = try await api.debugEnsureBackendToken()
                                // Save parsed token for display
                                let (h, c) = decodeJWTParts(token)
                                await MainActor.run {
                                    tokenHeader = h
                                    tokenClaims = c
                                    backendExchangeResult = "ensureBackendToken returned a token"
                                }
                            } catch {
                                await MainActor.run {
                                    backendExchangeResult = "ensureBackendToken failed: \(error.localizedDescription)"
                                }
                            }
                            #else
                            backendExchangeResult = "Debug-only: compile with DEBUG to enable"
                            #endif
                        } else {
                            backendExchangeResult = "APIManager not available"
                        }

                        // Fetch test recommendations via APIManager
                        if let api = authManager.apiManager {
                            do {
                                let recs = try await api.fetchTestRecommendations()
                                testResult = "Fetched \(recs.count) recommendations."
                                // Optionally update currentToken to trigger display
                                await MainActor.run {
                                    currentToken = KeychainHelper().getValue(for: "apple_id_token")
                                }
                                print("[Debug] Test recommendations: \(recs.map { $0.title })")
                            } catch {
                                testResult = "Failed to fetch test recs: \(error.localizedDescription)"
                            }
                        } else {
                            testResult = "APIManager not available"
                        }
                        isLoading = false
                    }
                } label: {
                    HStack {
                        Text("Fetch Test Recommendations")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }

                // Debug: Exchange Apple id_token with backend debug endpoint
                Section("Backend Exchange") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Raw id_token (paste to override keychain)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $manualToken)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray4)))
                    }

                    Button {
                        isLoading = true
                        Task {
                            #if DEBUG
                            guard let api = authManager.apiManager else {
                                backendExchangeResult = "APIManager not available"
                                isLoading = false
                                return
                            }

                            // Prefer manual token if provided, otherwise use keychain-stored token
                            let tokenToSend = manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KeychainHelper().getValue(for: "apple_id_token") : manualToken

                            guard let token = tokenToSend else {
                                backendExchangeResult = "No id_token available to send"
                                isLoading = false
                                return
                            }

                            do {
                                let (access, refresh) = try await api.debugSendAppleIdToken(token, email: KeychainHelper().getValue(for: "user_email"), firstName: nil, lastName: nil)
                                backendExchangeResult = "access: \(access.prefix(20))... refresh: \(refresh?.prefix(20) ?? "nil")"
                            } catch {
                                backendExchangeResult = "Error: \(error.localizedDescription)"
                            }
                            #else
                            backendExchangeResult = "Debug-only: compile with DEBUG to enable"
                            #endif

                            // Refresh displayed token from keychain if exchange saved a new app token
                            await MainActor.run {
                                currentToken = KeychainHelper().getValue(for: "apple_id_token")
                            }

                            isLoading = false
                        }
                    } label: {
                        HStack {
                            Text("Exchange id_token with backend (debug)")
                            Spacer()
                            if isLoading { ProgressView() }
                        }
                    }

                    if !backendExchangeResult.isEmpty {
                        Text(backendExchangeResult)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
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
            
            Section("Debug Actions") {
                Button("Show Apple ID Token Claims") {
                    if let token = KeychainHelper().getValue(for: "apple_id_token") {
                        do {
                            if let jwt = try decode(jwtToken: token) {
                                tokenClaims = "APPLE ID TOKEN:\n\n\(String(describing: jwt))"
                                
                                if let exp = jwt["exp"] as? TimeInterval {
                                    let expDate = Date(timeIntervalSince1970: exp)
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .medium
                                    
                                    tokenClaims += "\n\nExpires: \(formatter.string(from: expDate))"
                                    if expDate < Date() {
                                        tokenClaims += " (EXPIRED)"
                                    } else {
                                        let timeLeft = expDate.timeIntervalSince(Date())
                                        tokenClaims += " (Valid for \(Int(timeLeft / 60)) more minutes)"
                                    }
                                }
                                
                                currentToken = token
                            }
                        } catch {
                            tokenClaims = "Error decoding Apple ID token: \(error)"
                        }
                    } else {
                        tokenClaims = "No Apple ID token found"
                    }
                }
                
                Button("Show Backend Access Token Claims") {
                    if let token = KeychainHelper().getValue(for: "auth_access_token") {
                        do {
                            if let jwt = try decode(jwtToken: token) {
                                tokenClaims = "BACKEND ACCESS TOKEN:\n\n\(String(describing: jwt))"
                                
                                if let exp = jwt["exp"] as? TimeInterval {
                                    let expDate = Date(timeIntervalSince1970: exp)
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .medium
                                    
                                    tokenClaims += "\n\nExpires: \(formatter.string(from: expDate))"
                                    if expDate < Date() {
                                        tokenClaims += " (EXPIRED)"
                                    } else {
                                        let timeLeft = expDate.timeIntervalSince(Date())
                                        tokenClaims += " (Valid for \(Int(timeLeft / 60)) more minutes)"
                                    }
                                }
                                
                                currentToken = token
                            }
                        } catch {
                            tokenClaims = "Error decoding backend token: \(error)"
                        }
                    } else {
                        tokenClaims = "No backend access token found"
                    }
                }
                
                Button("Show Backend Refresh Token Claims") {
                    if let token = KeychainHelper().getValue(for: "auth_refresh_token") {
                        do {
                            if let jwt = try decode(jwtToken: token) {
                                tokenClaims = "BACKEND REFRESH TOKEN:\n\n\(String(describing: jwt))"
                                
                                if let exp = jwt["exp"] as? TimeInterval {
                                    let expDate = Date(timeIntervalSince1970: exp)
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .medium
                                    
                                    tokenClaims += "\n\nExpires: \(formatter.string(from: expDate))"
                                    if expDate < Date() {
                                        tokenClaims += " (EXPIRED)"
                                    } else {
                                        let timeLeft = expDate.timeIntervalSince(Date())
                                        tokenClaims += " (Valid for \(Int(timeLeft / 3600)) more hours)"
                                    }
                                }
                                
                                currentToken = token
                            }
                        } catch {
                            tokenClaims = "Error decoding refresh token: \(error)"
                        }
                    } else {
                        tokenClaims = "No backend refresh token found"
                    }
                }
                
                Button("Refresh Backend Token (Silent)") {
                    isLoading = true
                    Task {
                        #if DEBUG
                        guard let api = authManager.apiManager else {
                            backendExchangeResult = "APIManager not available"
                            isLoading = false
                            return
                        }
                        
                        do {
                            let result = try await api.debugEnsureBackendToken()
                            backendExchangeResult = "Token refreshed successfully"
                            
                            // Show the refreshed token details
                            if let jwt = try? decode(jwtToken: result) {
                                tokenClaims = "REFRESHED TOKEN:\n\n\(String(describing: jwt))"
                                
                                if let exp = jwt["exp"] as? TimeInterval {
                                    let expDate = Date(timeIntervalSince1970: exp)
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .medium
                                    
                                    tokenClaims += "\n\nExpires: \(formatter.string(from: expDate))"
                                    let timeLeft = expDate.timeIntervalSince(Date())
                                    tokenClaims += " (Valid for \(Int(timeLeft / 60)) more minutes)"
                                }
                                
                                currentToken = result
                            }
                        } catch {
                            backendExchangeResult = "Error refreshing token: \(error.localizedDescription)"
                        }
                        #else
                        backendExchangeResult = "Debug-only: compile with DEBUG to enable"
                        #endif
                        
                        isLoading = false
                    }
                }
                
                Button("Force Refresh Token") {
                    isLoading = true
                    Task {
                        #if DEBUG
                        guard let api = authManager.apiManager else {
                            backendExchangeResult = "APIManager not available"
                            isLoading = false
                            return
                        }
                        
                        // First clear existing tokens to force fresh exchange
                        KeychainHelper().removeValue(for: "auth_access_token")
                        KeychainHelper().removeValue(for: "auth_refresh_token")
                        
                        // Verify we still have Apple token
                        guard let appleToken = KeychainHelper().getValue(for: "apple_id_token") else {
                            backendExchangeResult = "❌ No Apple ID token found. Please sign in with Apple first."
                            isLoading = false
                            return
                        }
                        
                        do {
                            // Force new token exchange
                            if let newToken = await api.debugExchangeAppleIdTokenForBackendToken() {
                                backendExchangeResult = "✅ Successfully exchanged Apple token for new backend token"
                                currentToken = newToken
                                let (h, c) = decodeJWTParts(newToken)
                                tokenHeader = h
                                tokenClaims = c
                            } else {
                                backendExchangeResult = "❌ Token exchange failed"
                            }
                        } catch {
                            backendExchangeResult = "❌ Error during token exchange: \(error.localizedDescription)"
                        }
                        isLoading = false
                        #else
                        backendExchangeResult = "Debug-only feature"
                        isLoading = false
                        #endif
                    }
                }
                
                Button("Check AI Insights Access") {
                    isLoading = true
                    Task {
                        #if DEBUG
                        guard let api = authManager.apiManager else {
                            backendExchangeResult = "APIManager not available"
                            isLoading = false
                            return
                        }
                        
                        do {
                            // Try to fetch a sample insight to test connectivity and authentication
                            let insights = try await api.fetchAIInsights(forDay: Date())
                            backendExchangeResult = "✅ AI Insights access OK: \(insights.count) insights retrieved"
                        } catch {
                            backendExchangeResult = "❌ AI Insights access failed: \(error.localizedDescription)"
                        }
                        #else
                        backendExchangeResult = "Debug-only: compile with DEBUG to enable"
                        #endif
                        
                        isLoading = false
                    }
                }
            }
            
            if !backendExchangeResult.isEmpty {
                Section("API Result") {
                    Text(backendExchangeResult)
                        .font(.callout)
                        .foregroundStyle(backendExchangeResult.contains("Error") || backendExchangeResult.contains("❌") ? .red : .primary)
                        .textSelection(.enabled)
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
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Token Flow:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Get Apple ID token via Sign In with Apple")
                        Text("2. Exchange Apple ID token with backend for access token")
                        Text("3. Use access token for AI Insights and other endpoints")
                        Text("4. If access token expires, exchange Apple ID token again")
                        Text("5. If Apple ID token expires, user must re-authenticate")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Authentication Debug:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Use 'Show Apple ID Token Claims' to check Apple token")
                        Text("• Use 'Show Backend Access Token Claims' to check backend token")
                        Text("• Use 'Refresh Backend Token' to silently refresh without user interaction")
                        Text("• If both tokens are expired, user must re-authenticate with Apple")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section("Technical Details") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple ID Token:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• RS256 algorithm (asymmetric)")
                        Text("• Issued by Apple")
                        Text("• Short expiry (10 minutes)")
                        Text("• Verified by backend using Apple's public key")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Backend Access Token:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• HS256 algorithm (symmetric)")
                        Text("• Issued by GluCoPilot backend")
                        Text("• Medium expiry (1 hour)")
                        Text("• Used for all authenticated API calls")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Backend Refresh Token:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• HS256 algorithm (symmetric)")
                        Text("• Issued by GluCoPilot backend")
                        Text("• Long expiry (30 days)")
                        Text("• Currently not used by frontend (no /auth/refresh endpoint)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Endpoint Structure:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• /api/v1/auth/social-login - Exchange Apple ID token")
                        Text("• /api/v1/detailed-insights/day - Get insights for a day")
                        Text("• /api/v1/insights/generate - Generate insights (stateless)")
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
        .alert("Token Claims", isPresented: $showClaims) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = tokenClaims
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(tokenClaims)
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

fileprivate func getTokenExpiry(_ token: String) -> Date? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    
    // Decode the claims part
    var str = String(parts[1])
    // Add padding
    let rem = str.count % 4
    if rem > 0 {
        str += String(repeating: "=", count: 4 - rem)
    }
    str = str
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    
    guard let data = Data(base64Encoded: str),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? TimeInterval else {
        return nil
    }
    
    return Date(timeIntervalSince1970: exp)
}

fileprivate func decode(jwtToken jwt: String) throws -> [String: Any]? {
    let segments = jwt.components(separatedBy: ".")
    guard segments.count > 1 else { return nil }
    
    var base64 = segments[1]
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    
    let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
    let requiredLength = 4 * ceil(length / 4.0)
    let paddingLength = requiredLength - length
    if paddingLength > 0 {
        let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
        base64 = base64 + padding
    }
    
    guard let data = Data(base64Encoded: base64) else {
        throw NSError(domain: "JWTDecodeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't decode base64"])
    }
    
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    return json as? [String: Any]
}

#Preview {
    NavigationStack {
        AppleSignInDebugView()
            .environmentObject(AuthenticationManager())
    }
}
