import SwiftUI
import HealthKit

struct OnboardingLegacyView: View {
    let apiManager: APIManager
    let dexcomManager: DexcomManager
    let healthKitManager: HealthKitManager
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    let totalSteps = 2
    
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
                            currentStep += 1
                        }
                    }) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        // Complete onboarding
                        onComplete()
                    }) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
            
            if healthKitManager.authorizationStatus == .sharingAuthorized {
                Text("HealthKit Connected ✓")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
            
            Spacer().frame(height: 20)
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
