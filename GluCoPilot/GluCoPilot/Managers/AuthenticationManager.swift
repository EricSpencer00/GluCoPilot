import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userDisplayName: String?
    @Published var userEmail: String?
    
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
        let displayName = credential.fullName?.formatted() ?? "User"
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
        
        print("Apple Sign In successful for user: \(displayName)")
    }
    
    func signOut() {
        // Clear keychain
        keychain.deleteValue(for: "apple_user_id")
        keychain.deleteValue(for: "user_display_name")
        keychain.deleteValue(for: "user_email")
        
        // Clear state
        isAuthenticated = false
        userDisplayName = nil
        userEmail = nil
        
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
