import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red.gradient)
                
                Text("GluCoPilot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("AI-Powered Diabetes Management")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Features List
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", 
                          title: "Glucose Integration",
                          description: "Connect your CGM or Apple Health for real-time glucose data")
                
                FeatureRow(icon: "heart.fill", 
                          title: "Health Data Sync",
                          description: "Import activity and health metrics")
                
                FeatureRow(icon: "brain.head.profile", 
                          title: "AI Insights",
                          description: "Personalized recommendations powered by AI")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Sign In Button
            VStack(spacing: 16) {
                if let error = authManager.authError {
                    VStack(spacing: 8) {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            authManager.authError = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }

                SignInWithAppleButton(.signIn) { request in
                    authManager.handleSignInRequest(request)
                } onCompletion: { result in
                    authManager.handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(25)
                .disabled(authManager.isLoadingAuth)

                Text(authManager.isLoadingAuth ? "Signing in…" : "Secure authentication with Apple ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AppleSignInView()
        .environmentObject(AuthenticationManager())
}
