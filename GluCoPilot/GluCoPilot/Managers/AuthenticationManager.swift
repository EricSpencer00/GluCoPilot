import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userDisplayName: String?
    @Published var userEmail: String?
    @Published var isRegistering = false
    @Published var showDexcomPrompt = false
    
    // This dependency is initialized in ContentView and passed to AuthManager
    var apiManager: APIManager?
    
    private let keychain = KeychainHelper()
    
    override init() {
        super.init()
        checkAuthenticationState()
    }
    
    func checkAuthenticationState() {
        // Check if we have stored credentials
        if let userID = keychain.getValue(for: "apple_user_id") {
            isAuthenticated = true
            userDisplayName = keychain.getValue(for: "user_display_name")
            userEmail = keychain.getValue(for: "user_email")
            
            // Check if Dexcom should be prompted
            if keychain.getValue(for: "has_seen_dexcom_prompt") != "true" {
                showDexcomPrompt = true
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
    
    func signOut() {
        // Clear keychain
        keychain.removeValue(for: "apple_user_id")
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
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed with error: \(error.localizedDescription)")
    }
}
