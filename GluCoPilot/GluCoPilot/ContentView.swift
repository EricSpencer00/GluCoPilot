import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var apiManager = APIManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isLaunching = true
    @State private var showOnboarding = false
    
    
    var body: some View {
        ZStack {
            if isLaunching {
                LaunchScreen()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // If the auth manager flagged that HealthKit authorization is required, show setup.
                // Otherwise, fall back to the persisted flag / normal flow.
                let completedSetup = UserDefaults.standard.bool(forKey: "hasCompletedHealthKitSetup")
                let hkAuthorized = healthKitManager.authorizationStatus == .sharingAuthorized

                if authManager.requiresHealthKitAuthorization || (!completedSetup && !hkAuthorized) {
                    HealthKitSetupView(onComplete: {
                        UserDefaults.standard.set(true, forKey: "hasCompletedHealthKitSetup")
                        // When user completes setup, clear the requirement so the app can proceed
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
                }
            } else {
                if showOnboarding {
                    OnboardingView(onComplete: {
                        showOnboarding = false
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
        .animation(.easeInOut(duration: 0.5), value: showOnboarding)
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
                    // Show onboarding for new users
                    if !authManager.isAuthenticated && !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                        showOnboarding = true
                    }
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                showOnboarding = false
            }
        }
    }
}

    // DexcomPromptView removed. Dexcom integration deprecated in favor of HealthKit.

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    
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
                                completeOnboarding()
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
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
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