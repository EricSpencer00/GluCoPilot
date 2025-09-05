import SwiftUI

struct ContentView: View {
    // Use environment objects instead of creating new instances
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if appState.isLaunching {
                LaunchScreen()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // If the auth manager flagged that HealthKit authorization is required, show setup.
                // Otherwise, fall back to the persisted flag / normal flow.
                let hkAuthorized = healthKitManager.authorizationStatus == .sharingAuthorized

                if authManager.requiresHealthKitAuthorization || !appState.hasCompletedHealthKitSetup || !hkAuthorized {
                    HealthKitSetupView(onComplete: {
                        appState.completeHealthKitSetup()
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
                    if !appState.hasSeenOnboarding {
                        OnboardingView(onComplete: {
                            appState.completeOnboarding()
                        })
                        .transition(.move(edge: .trailing))
                    } else {
                        AppleSignInView()
                            .environmentObject(authManager)
                            .transition(.move(edge: .leading))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: appState.isLaunching)
        .animation(.easeInOut(duration: 0.6), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.5), value: appState.hasSeenOnboarding)
        // No need to duplicate environmentObject modifiers or onAppear tasks
        // as they're now handled in GluCoPilotApp
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
                    .accessibilityHidden(true)
                
                Image(systemName: page.systemImage)
                    .font(.system(size: 50))
                    .foregroundColor(page.color)
                    .accessibilityLabel("Illustration for \(page.title)")
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
            .accessibilityElement(children: .combine)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager())
        .environmentObject(APIManager())
}