import SwiftUI
import HealthKit
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    let apiManager: APIManager
    let dexcomManager: DexcomManager
    let healthKitManager: HealthKitManager
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var isSignInWithAppleComplete = false
    @State private var isHealthKitComplete = false
    let totalSteps = 3
    
    var body: some View {
        VStack {
            // Progress indicator
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 20)
            
            // Step content
            ScrollView {
                VStack(spacing: 20) {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        signInStep
                    case 2:
                        healthKitStep
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Spacer()
                }
                
                if currentStep < totalSteps - 1 {
                    Button(action: {
                        withAnimation {
                            if currentStep == 1 && !isSignInWithAppleComplete {
                                // Don't proceed if sign in is not complete
                                return
                            }
                            currentStep += 1
                        }
                    }) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStep == 1 && !isSignInWithAppleComplete)
                } else {
                    Button(action: {
                        // Complete onboarding
                        onComplete()
                    }) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isHealthKitComplete)
                }
            }
            .padding()
        }
    }
    
    // Welcome step
    var welcomeStep: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to GluCoPilot")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered diabetes management assistant")
                .font(.title3)
                .multilineTextAlignment(.center)
            
            Text("GluCoPilot helps you monitor your glucose levels and provides personalized insights to help you manage your health better.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer().frame(height: 30)
        }
    }
    
    // Sign In step
    var signInStep: some View {
        VStack(spacing: 30) {
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Sign in with Apple")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sign in securely with your Apple ID to personalize your experience and save your data.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            SignInWithAppleButton(.signIn) { request in
                authManager.handleSignInRequest(request)
            } onCompletion: { result in
                authManager.handleSignInResult(result)
                // Mark as complete if authentication is successful
                if case .success = result {
                    isSignInWithAppleComplete = true
                    // Automatically proceed to next step after successful sign in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
            .padding(.horizontal)
            
            if isSignInWithAppleComplete || authManager.isAuthenticated {
                Text("Sign In Complete ✓")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
            
            Spacer().frame(height: 30)
        }
        .onAppear {
            // Check if already authenticated
            if authManager.isAuthenticated {
                isSignInWithAppleComplete = true
            }
        }
    }
    
    // HealthKit step
    var healthKitStep: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Connect to HealthKit")
                .font(.title)
                .fontWeight(.bold)
            
            Text("GluCoPilot uses your HealthKit data to provide personalized insights.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                InfoRow(icon: "heart.fill", color: .red, text: "Heart Rate")
                InfoRow(icon: "flame.fill", color: .orange, text: "Active Energy")
                InfoRow(icon: "figure.walk", color: .green, text: "Steps & Workouts")
                InfoRow(icon: "bed.double.fill", color: .indigo, text: "Sleep Analysis")
                InfoRow(icon: "drop.fill", color: .red, text: "Blood Glucose")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button(action: {
                Task {
                    await healthKitManager.requestAuthorization()
                    // Mark as complete after attempting to request authorization
                    isHealthKitComplete = true
                }
            }) {
                Label("Connect HealthKit", systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(healthKitManager.authorizationStatus == .sharingAuthorized)
            
            if healthKitManager.authorizationStatus == .sharingAuthorized || isHealthKitComplete {
                Text("HealthKit Connected ✓")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
            
            Spacer().frame(height: 20)
        }
        .onAppear {
            // Check current authorization status when this view appears
            if healthKitManager.authorizationStatus == .sharingAuthorized {
                isHealthKitComplete = true
            }
        }
    }
}

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}
