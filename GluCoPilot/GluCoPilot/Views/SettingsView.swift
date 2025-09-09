import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthManager: HealthKitManager
    @State private var showLogoutAlert = false
    @AppStorage("showHealthKitPermissionLogs") private var showHealthKitPermissionLogs: Bool = false
    
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
                // Glucose Source (HealthKit)
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 25)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health (HealthKit)")
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
                
                
                NavigationLink {
                    DataPrivacyView()
                        .environmentObject(healthManager)
                } label: {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(.green)
                            .frame(width: 25)

                        Text("Data & Privacy")
                            .font(.subheadline)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                NavigationLink {
                    StaticDocumentView(title: "Terms of Service", content: StaticDocumentView.termsPlaceholder)
                } label: {
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

            // HealthKit logs toggle
            Section("HealthKit") {
                Toggle("Show HealthKit permission logs", isOn: $showHealthKitPermissionLogs)
                    .font(.subheadline)
                Text("Enable this to see detailed HealthKit permission messages in the console. Useful for debugging permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Support Section
            Section("Support") {
                NavigationLink {
                    StaticDocumentView(title: "Help & Support", content: StaticDocumentView.helpPlaceholder)
                } label: {
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

                NavigationLink {
                    StaticDocumentView(title: "Contact Us", content: StaticDocumentView.contactPlaceholder)
                } label: {
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
            
            // DEBUG Section - Remove for production
            #if DEBUG
            // Debug navigation links intentionally disabled for production-like UI.
            // To re-enable for development, uncomment the NavigationLink below.
            /*
            Section("Debug Options") {
                NavigationLink {
                    AppleSignInDebugView()
                        .environmentObject(authManager)
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 25)
                        
                        Text("Test Apple Sign In")
                            .font(.subheadline)
                    }
                }
            }
            */
            #endif
            
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
    // Dexcom disconnect UI removed; integration deprecated.
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthenticationManager())
            .environmentObject(HealthKitManager())
    }
}
