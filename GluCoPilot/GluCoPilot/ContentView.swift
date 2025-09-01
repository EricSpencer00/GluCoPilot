import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var apiManager = APIManager()
    @StateObject private var dexcomManager = DexcomManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isLaunching = true
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            if isLaunching {
                LaunchScreen()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(apiManager)
                    .environmentObject(dexcomManager)
                    .environmentObject(healthKitManager)
                    .environmentObject(authManager)
                    .transition(.move(edge: .bottom))
            } else {
                if showOnboarding {
                    OnboardingView(
                        apiManager: apiManager,
                        dexcomManager: dexcomManager,
                        healthKitManager: healthKitManager,
                        onComplete: {
                            showOnboarding = false
                        }
                    )
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
            
            // Simulate launch time and check authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                isLaunching = false
                authManager.checkAuthenticationStatus()
                
                // Show onboarding for new users
                if !authManager.isAuthenticated && !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                    showOnboarding = true
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

struct DexcomPromptView: View {
    let apiManager: APIManager
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @StateObject private var dexcomManager = DexcomManager()
    @State private var username = ""
    @State private var password = ""
    @State private var isInternational = false
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Connect Dexcom")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("For the best experience, connect your Dexcom CGM account to get real-time glucose data.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                            
                            TextField("Dexcom Share username", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                            
                            SecureField("Dexcom Share password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Toggle("Outside US (International)", isOn: $isInternational)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                        
                        Button(action: connectDexcom) {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Connect")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(username.isEmpty || password.isEmpty || isConnecting)
                        
                        Button("Skip for now", action: onSkip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Connect Dexcom")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Connection Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func connectDexcom() {
        isConnecting = true
        
        Task {
            do {
                try await dexcomManager.connect(
                    username: username,
                    password: password,
                    isInternational: isInternational,
                    apiManager: apiManager
                )
                
                await MainActor.run {
                    isConnecting = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct OnboardingView: View {
    let apiManager: APIManager
    let dexcomManager: DexcomManager
    let healthKitManager: HealthKitManager
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    @State private var showDexcomSetup = false
    @State private var dexcomUsername = ""
    @State private var dexcomPassword = ""
    @State private var isInternational = false
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
            description: "Connect your Dexcom CGM and Apple Health to automatically track your glucose levels and health metrics.",
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
                            Button("Connect Data Sources") {
                                showDataConnectionOptions()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .sheet(isPresented: $showDexcomSetup) {
                DexcomSetupView(
                    apiManager: apiManager,
                    dexcomManager: dexcomManager,
                    username: $dexcomUsername,
                    password: $dexcomPassword,
                    isInternational: $isInternational,
                    isConnecting: $isConnecting,
                    showError: $showError,
                    errorMessage: $errorMessage
                )
            }
        }
    }
    
    @State private var showingDataConnectionView = false
    
    private func showDataConnectionOptions() {
        withAnimation(.spring()) {
            // The final page will be a custom data connection page
            currentPage = onboardingPages.count
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onComplete()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), currentPage < onboardingPages.count ? onboardingPages[currentPage].color.opacity(0.1) : .blue.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                if currentPage < onboardingPages.count {
                    // Regular onboarding pages
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
                            }
                        }
                        
                        HStack {
                            if currentPage > 0 {
                                Button("Back") {
                                    withAnimation(.spring()) {
                                        currentPage -= 1
                                    }
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Spacer()
                                    .frame(width: 60)
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
                                Button("Connect Data Sources") {
                                    showDataConnectionOptions()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                } else {
                    // Data Connection View
                    VStack(spacing: 25) {
                        VStack(spacing: 16) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Connect Your Data")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Choose which data sources to connect")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // HealthKit Button
                        Button(action: {
                            healthKitManager.requestHealthKitPermissions()
                        }) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading) {
                                    Text("Apple Health")
                                        .font(.headline)
                                    
                                    Text("Connect activity, nutrition & more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // Dexcom Button
                        Button(action: {
                            showDexcomSetup = true
                        }) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Dexcom CGM")
                                        .font(.headline)
                                    
                                    Text("Connect your Dexcom Share account")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Get Started button
                        Button(action: completeOnboarding) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let color: Color
}

struct DexcomSetupView: View {
    let apiManager: APIManager
    let dexcomManager: DexcomManager
    @Binding var username: String
    @Binding var password: String
    @Binding var isInternational: Bool
    @Binding var isConnecting: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Connect Dexcom")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter your Dexcom Share account credentials to sync your CGM data.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                            
                            TextField("Dexcom Share username", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                            
                            SecureField("Dexcom Share password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Toggle("Outside US (International)", isOn: $isInternational)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                        
                        Button(action: connectDexcom) {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Connect")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(username.isEmpty || password.isEmpty || isConnecting)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Connect Dexcom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Connection Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func connectDexcom() {
        isConnecting = true
        
        Task {
            do {
                try await dexcomManager.connect(
                    username: username,
                    password: password,
                    isInternational: isInternational,
                    apiManager: apiManager
                )
                
                await MainActor.run {
                    isConnecting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
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
