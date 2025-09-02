import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var apiManager: APIManager
    @EnvironmentObject private var dexcomManager: DexcomManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isLaunching = true
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            if isLaunching {
                LaunchScreen()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                MainTabView()
                    .transition(.move(edge: .bottom))
            } else {
                OnboardingView(
                    apiManager: apiManager,
                    dexcomManager: dexcomManager,
                    healthKitManager: healthKitManager,
                    onComplete: {
                        // Mark onboarding as completed
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    }
                )
                .environmentObject(authManager)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.8), value: isLaunching)
        .animation(.easeInOut(duration: 0.6), value: authManager.isAuthenticated)
        .onAppear {
            // Simulate launch time and check authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                isLaunching = false
                authManager.checkAuthenticationStatus()
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
