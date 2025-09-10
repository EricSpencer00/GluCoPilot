import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var apiManager: APIManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isLaunching = true
    @State private var onboardingState: OnboardingState = .none
    @State private var showSkippedWarning = false
    
    enum OnboardingState {
        case none
        case welcome
        case medicalDisclaimer
        case healthKitSetup
    }
    
    init() {
        // Migrate old UserDefaults keys to new consolidated flow
        migrateUserDefaultsIfNeeded()
    }
    
    // Function to migrate existing UserDefaults to new consolidated flow
    private func migrateUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        
        // Check if we've already migrated
        if defaults.bool(forKey: "hasMigratedOnboardingKeys") {
            return
        }
        
        // Migrate old keys to new keys
        let hasAcceptedMedicalDisclaimer = defaults.bool(forKey: "hasAcceptedMedicalDisclaimer")
        let hasCompletedHealthKitSetup = defaults.bool(forKey: "hasCompletedHealthKitSetup")
        let hasSeenOnboarding = defaults.bool(forKey: "hasSeenOnboarding")
        
        // Set new consolidated keys
        if hasAcceptedMedicalDisclaimer {
            defaults.set(true, forKey: "hasCompletedMedicalDisclaimer")
        }
        
        if hasCompletedHealthKitSetup {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
        
        if hasSeenOnboarding {
            defaults.set(true, forKey: "hasCompletedWelcomeOnboarding")
        }
        
        // If user completed HealthKit setup and accepted medical disclaimer, 
        // they've completed onboarding
        if hasAcceptedMedicalDisclaimer && hasCompletedHealthKitSetup {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
        
        // Mark migration as complete
        defaults.set(true, forKey: "hasMigratedOnboardingKeys")
    }
    
    
    var body: some View {
        ZStack {
            if isLaunching {
                LaunchScreen()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // Check onboarding completion status
                if onboardingState == .medicalDisclaimer {
                    MedicalDisclaimerView(onAccept: {
                        UserDefaults.standard.set(true, forKey: "hasCompletedMedicalDisclaimer")
                        // Move to HealthKit setup after medical disclaimer
                        onboardingState = .healthKitSetup
                    })
                    .transition(.move(edge: .bottom))
                } else if onboardingState == .healthKitSetup {
                    HealthKitSetupView(onComplete: {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        // Complete the onboarding
                        onboardingState = .none
                        // Clear the requirement so the app can proceed
                        authManager.requiresHealthKitAuthorization = false
                    })
                    .environmentObject(apiManager)
                    .environmentObject(healthKitManager)
                    .environmentObject(authManager)
                    .transition(.move(edge: .trailing))
                } else {
                    MainTabView()
                        .environmentObject(apiManager)
                        .environmentObject(healthKitManager)
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            // Check if user skipped HealthKit setup
                            if UserDefaults.standard.bool(forKey: "hasSkippedHealthKitSetup") && 
                               !UserDefaults.standard.bool(forKey: "hasAcknowledgedLimitedFunctionality") {
                                showSkippedWarning = true
                            }
                        }
                }
            } else {
                if onboardingState == .welcome {
                    OnboardingView(onComplete: {
                        UserDefaults.standard.set(true, forKey: "hasCompletedWelcomeOnboarding")
                        onboardingState = .none
                    })
                    .transition(.move(edge: .trailing))
                } else {
                    AppleSignInView()
                        .environmentObject(authManager)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: isLaunching)
        .animation(.easeInOut(duration: 0.6), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.5), value: onboardingState)
        .environmentObject(authManager)
        .onAppear {
            // Inject the apiManager dependency
            authManager.apiManager = apiManager
            // Inject HealthKitManager dependency outside the view builder
            authManager.healthKitManager = healthKitManager
            
            // Perform readiness checks immediately and show launch screen for a short minimum time
            Task {
                // Kick off auth check which may trigger async token refresh
                authManager.checkAuthenticationStatus()

                // Keep the launch screen visible at least briefly for polish
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await MainActor.run {
                    isLaunching = false
                    
                    // Determine the onboarding state
                    if authManager.isAuthenticated {
                        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                        let hasCompletedMedicalDisclaimer = UserDefaults.standard.bool(forKey: "hasCompletedMedicalDisclaimer")
                        
                        if !hasCompletedOnboarding {
                            if !hasCompletedMedicalDisclaimer {
                                onboardingState = .medicalDisclaimer
                            } else {
                                onboardingState = .healthKitSetup
                            }
                        }
                    } else {
                        // Show welcome onboarding for new users who aren't authenticated
                        if !UserDefaults.standard.bool(forKey: "hasCompletedWelcomeOnboarding") {
                            onboardingState = .welcome
                        }
                    }
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // When user authenticates, check if they need to see the medical disclaimer
                if !UserDefaults.standard.bool(forKey: "hasCompletedMedicalDisclaimer") {
                    onboardingState = .medicalDisclaimer
                } else if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                    onboardingState = .healthKitSetup
                }
            }
        }
        .alert("Limited Functionality", isPresented: $showSkippedWarning) {
            Button("Connect HealthKit") {
                // Reset the skipped flag
                UserDefaults.standard.set(false, forKey: "hasSkippedHealthKitSetup")
                // Show the HealthKit setup again
                onboardingState = .healthKitSetup
                showSkippedWarning = false
            }
            Button("Continue Limited") {
                // Mark that user has acknowledged the limited functionality
                UserDefaults.standard.set(true, forKey: "hasAcknowledgedLimitedFunctionality")
                showSkippedWarning = false
            }
        } message: {
            Text("Without HealthKit access, GluCoPilot will have limited functionality. You won't be able to see glucose trends, health metrics, or get personalized insights.")
        }
    }
}

    // DexcomPromptView removed. Dexcom integration deprecated in favor of HealthKit.

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @State private var showConsentView = false
    @State private var userConsented = false
    
    private let onboardingPages = [
        OnboardingPage(
            title: "Welcome to GluCoPilot",
            subtitle: "Your AI-powered diabetes management companion",
            description: "Get personalized insights and recommendations based on your glucose readings and health data.",
            systemImage: "brain.head.profile.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Connect Your Devices",
            subtitle: "Seamless data integration",
                description: "Connect your Apple Health integration to automatically track your glucose levels and health metrics.",
            systemImage: "heart.circle.fill",
            color: .red
        ),
        OnboardingPage(
            title: "AI-Powered Insights",
            subtitle: "Personalized recommendations",
            description: "Our advanced AI analyzes your data patterns to provide actionable insights for better diabetes management.",
            systemImage: "sparkles",
            color: .purple
        ),
        OnboardingPage(
            title: "Take Control",
            subtitle: "Empower your health journey",
            description: "Make informed decisions with real-time data, trends analysis, and predictive insights.",
            systemImage: "chart.line.uptrend.xyaxis.circle.fill",
            color: .green
        )
    ]
    
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), onboardingPages[currentPage].color.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Onboarding content
                TabView(selection: $currentPage) {
                    ForEach(Array(onboardingPages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page indicators and navigation
                VStack(spacing: 30) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? onboardingPages[currentPage].color : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button("Previous") {
                                withAnimation(.spring()) {
                                    currentPage -= 1
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if currentPage < onboardingPages.count - 1 {
                            Button("Next") {
                                withAnimation(.spring()) {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        } else {
                            Button("Get Started") {
                                showConsentView = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showConsentView) {
            ConsentView(
                onAccept: {
                    userConsented = true
                    completeOnboarding()
                },
                onDecline: {
                    showConsentView = false
                    // Optionally handle decline action (e.g., show additional information)
                }
            )
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcomeOnboarding")
        UserDefaults.standard.set(userConsented, forKey: "hasConsentedToDataCollection")
        onComplete()
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.systemImage)
                    .font(.system(size: 50))
                    .foregroundColor(page.color)
            }
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(page.color)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}