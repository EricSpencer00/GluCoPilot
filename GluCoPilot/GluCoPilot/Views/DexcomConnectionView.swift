import SwiftUI

struct DexcomConnectionView: View {
    @EnvironmentObject var dexcomManager: DexcomManager
    @EnvironmentObject var apiManager: APIManager
    @State private var username = ""
    @State private var password = ""
    @State private var isInternational = false
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Connect Dexcom")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter your Dexcom Share credentials to sync your glucose data. This is the same username and password you use for the Dexcom app.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Connection Form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        TextField("Dexcom username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        SecureField("Dexcom password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // International Toggle
                    HStack {
                        Toggle("Outside US (International)", isOn: $isInternational)
                            .font(.subheadline)
                    }
                    
                    // Connect Button
                    Button(action: connectToDexcom) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isConnecting ? "Connecting..." : "Connect Dexcom")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(username.isEmpty || password.isEmpty || isConnecting)
                    .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal)
                
                // Security Notice
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                        Text("Your credentials are securely encrypted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("GluCoPilot does not store your password in plain text and only uses it to access your Dexcom data.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Dexcom Setup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connectToDexcom() {
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
                    // Navigation will happen automatically due to state change
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

#Preview {
    NavigationStack {
        DexcomConnectionView()
            .environmentObject(DexcomManager())
    }
}
