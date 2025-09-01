import Foundation
import AuthenticationServices
import SwiftUI
import UIKit

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userDisplayName: String?
    @Published var userEmail: String?
    @Published var isRegistering = false
    @Published var showDexcomPrompt = false
    @Published var currentIdToken: String? = nil
    
    // This dependency is initialized in ContentView and passed to AuthManager
    var apiManager: APIManager?
    
    private let keychain = KeychainHelper()
    // Continuation used when programmatically requesting a new Apple credential
    private var authContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential?, Never>? = nil
    
    override init() {
        super.init()
        checkAuthenticationState()
    }
    
    func checkAuthenticationState() {
        // Check if we have stored credentials
        if keychain.getValue(for: "apple_user_id") != nil {
            isAuthenticated = true
            userDisplayName = keychain.getValue(for: "user_display_name")
            userEmail = keychain.getValue(for: "user_email")
            
            // Check if Dexcom should be prompted
            if keychain.getValue(for: "has_seen_dexcom_prompt") != "true" {
                showDexcomPrompt = true
            }
            // If apple_user_id exists but apple_id_token is missing, try to obtain a fresh id_token
            if keychain.getValue(for: "apple_id_token") == nil {
                print("[AuthManager] apple_user_id present but apple_id_token missing — attempting interactive refresh")
                
                #if targetEnvironment(simulator)
                // Create a development-only fallback token for simulator testing
                // THIS IS FOR DEVELOPMENT ONLY - not for production use
                print("[AuthManager] Running in simulator - using development fallback token")
                let fallbackToken = "dev_simulator_token_\(UUID().uuidString)"
                keychain.setValue(fallbackToken, for: "apple_id_token")
                self.currentIdToken = fallbackToken
                UserDefaults.standard.set(Date(), forKey: "apple_id_token_timestamp")
                print("[AuthManager] Created development fallback token for simulator")
                #else
                // On real device, attempt interactive refresh
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        if let credential = await self.requestAppleIDCredential() {
                            // Save token if present
                                          if let identityToken = credential.identityToken,
                                              let idTokenString = String(data: identityToken, encoding: .utf8) {
                                                self.keychain.setValue(idTokenString, for: "apple_id_token")
                                                self.currentIdToken = idTokenString
                                                UserDefaults.standard.set(Date(), forKey: "apple_id_token_timestamp")
                                                print("[AuthManager] Refreshed apple_id_token and saved to keychain")
                                                // Optionally re-register with backend
                                                await self.registerWithBackend(userID: credential.user, fullName: credential.fullName?.formatted() ?? "User", email: credential.email)
                            } else {
                                print("[AuthManager] Interactive refresh returned no identityToken")
                            }
                        } else {
                            print("[AuthManager] Interactive Apple sign-in cancelled or failed")
                        }
                    } catch {
                        print("[AuthManager] Error during interactive refresh: \(error.localizedDescription)")
                    }
                }
                #endif
            }
        }
    }
    
    // Alias for compatibility
    func checkAuthenticationStatus() {
        checkAuthenticationState()
    }
    
    func handleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                handleSuccessfulSignIn(credential: appleIDCredential)
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func handleSuccessfulSignIn(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user
        let fullName = credential.fullName
        let displayName = fullName?.formatted() ?? "User"
        let email = credential.email
        
        // Store credentials securely
        keychain.setValue(userID, for: "apple_user_id")
        keychain.setValue(displayName, for: "user_display_name")
        if let email = email {
            keychain.setValue(email, for: "user_email")
        }

        // Save the raw Apple id_token (JWT) so backend can verify the token signature.
        if let identityToken = credential.identityToken,
           let idTokenString = String(data: identityToken, encoding: .utf8) {
            keychain.setValue(idTokenString, for: "apple_id_token")
            currentIdToken = idTokenString
            UserDefaults.standard.set(Date(), forKey: "apple_id_token_timestamp")
        }
        
        // Update state
        isAuthenticated = true
        userDisplayName = displayName
        userEmail = email
        showDexcomPrompt = true
        
        // Register with backend
        Task {
            await registerWithBackend(userID: userID, fullName: displayName, email: email)
        }
        
        print("Apple Sign In successful for user: \(displayName)")
    }

    // Async helper to request a fresh ASAuthorizationAppleIDCredential via an interactive sign-in
    private func requestAppleIDCredential() async -> ASAuthorizationAppleIDCredential? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential?, Never>) in
            // Save continuation so delegate can resume
            self.authContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            
            // Use Task to avoid potential thread issues
            Task { @MainActor in
                do {
                    controller.performRequests()
                } catch {
                    print("[AuthManager] Error performing auth requests: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    self.authContinuation = nil
                }
            }
        }
    }
    
    private func registerWithBackend(userID: String, fullName: String, email: String?) async {
        guard let apiManager = apiManager else {
            print("APIManager not available for registration")
            return
        }
        
        isRegistering = true
        
        do {
            let success = try await apiManager.registerWithAppleID(
                userID: userID,
                fullName: fullName,
                email: email
            )
            
            if success {
                print("Successfully registered with backend")
            }
        } catch {
            print("Error registering with backend: \(error.localizedDescription)")
            // We don't fail the sign-in if backend registration fails
            // The app should still work locally
        }
        
        isRegistering = false
    }
    
    func acknowledgeeDexcomPrompt() {
        keychain.setValue("true", for: "has_seen_dexcom_prompt")
        showDexcomPrompt = false
    }
    
    // Debug function to test Apple Sign In directly
    func testAppleSignIn() async -> String {
        print("[AuthManager] Testing Apple Sign In...")
        
        do {
            // Check if we already have a token
            if let existingToken = keychain.getValue(for: "apple_id_token") {
                print("[AuthManager] Existing token found")
                // ensure published copy is up-to-date
                self.currentIdToken = existingToken
                return "Existing token: \(existingToken.prefix(15))..."
            }
            
            print("[AuthManager] No existing token, requesting new one...")
            if let credential = await requestAppleIDCredential() {
                if let identityToken = credential.identityToken,
                   let idTokenString = String(data: identityToken, encoding: .utf8) {
                    keychain.setValue(idTokenString, for: "apple_id_token")
                    self.currentIdToken = idTokenString
                    UserDefaults.standard.set(Date(), forKey: "apple_id_token_timestamp")
                    print("[AuthManager] New token obtained and saved")
                    return "New token obtained: \(idTokenString.prefix(15))..."
                } else {
                    return "Error: Credential obtained but no identity token present"
                }
            } else {
                return "Error: Sign in cancelled or failed"
            }
        } catch {
            return "Error during sign in: \(error.localizedDescription)"
        }
    }
    
    func signOut() {
        // Clear keychain
        keychain.removeValue(for: "apple_user_id")
        keychain.removeValue(for: "apple_id_token")
    currentIdToken = nil
        keychain.removeValue(for: "user_display_name")
        keychain.removeValue(for: "user_email")
        keychain.removeValue(for: "has_seen_dexcom_prompt")
        
        // Clear state
        isAuthenticated = false
        userDisplayName = nil
        userEmail = nil
        showDexcomPrompt = false
        
        print("User signed out")
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            handleSuccessfulSignIn(credential: appleIDCredential)
            // Resume any awaiting continuation
            if let cont = authContinuation {
                cont.resume(returning: appleIDCredential)
                authContinuation = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed with error: \(error.localizedDescription)")
        // Resume continuation with nil to indicate failure/cancel
        if let cont = authContinuation {
            cont.resume(returning: nil)
            authContinuation = nil
        }
    }
}

// Provide a presentation anchor for ASAuthorizationController
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // This is a more reliable way to get the key window in SwiftUI apps
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        return window
    }
}
