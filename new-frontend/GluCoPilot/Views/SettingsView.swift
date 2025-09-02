import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dexcomManager: DexcomManager
    @EnvironmentObject var healthManager: HealthKitManager
    @State private var showLogoutAlert = false
    @State private var showDexcomDisconnectAlert = false
    
    var body: some View {
        List {
            // User Section
            Section {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userDisplayName ?? "User")
                            .font(.headline)
                        
                        Text("Signed in with Apple")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Connections Section
            Section("Connections") {
                // Dexcom Connection
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 25)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dexcom")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(dexcomManager.isConnected ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundStyle(dexcomManager.isConnected ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if dexcomManager.isConnected {
                        Button("Disconnect") {
                            showDexcomDisconnectAlert = true
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                
                // Apple Health Connection
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 25)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(healthManager.isHealthKitAvailable ? "Available" : "Not Available")
                            .font(.caption)
                            .foregroundStyle(healthManager.isHealthKitAvailable ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Button("Manage") {
                        healthManager.requestHealthKitPermissions()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            // App Info Section
            Section("App Information") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                        .frame(width: 25)
                    
                    Text("Version")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.green)
                        .frame(width: 25)
                    
                    Text("Privacy Policy")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundStyle(.green)
                                .frame(width: 25)
                            Text("Privacy Policy")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.blue)
                        .frame(width: 25)
                    
                    Text("Terms of Service")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.blue)
                                .frame(width: 25)
                            Text("Terms of Service")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
            
            // Support Section
            Section("Support") {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.blue)
                        .frame(width: 25)
                    
                    Text("Help & Support")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                    NavigationLink(destination: HelpSupportView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.blue)
                                .frame(width: 25)
                            Text("Help & Support")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(.blue)
                        .frame(width: 25)
                    
                    Text("Contact Us")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                    NavigationLink(destination: ContactUsView()) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(.blue)
                                .frame(width: 25)
                            Text("Contact Us")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
            
            // Sign Out Section
            Section {
                Button(action: { showLogoutAlert = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                            .frame(width: 25)
                        
                        Text("Sign Out")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
        }
        .alert("Disconnect Dexcom", isPresented: $showDexcomDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                dexcomManager.disconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect your Dexcom account? You'll need to reconnect to sync glucose data.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthenticationManager())
            .environmentObject(DexcomManager())
            .environmentObject(HealthKitManager())
    }
}
