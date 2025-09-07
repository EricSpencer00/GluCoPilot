import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var showWelcome = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.9), .purple.opacity(0.7), .pink.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle glossy overlay to add depth
            LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .blendMode(.overlay)
            
            VStack(spacing: 30) {
                // App icon animation
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Image(systemName: "drop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                // App name and tagline
                VStack(spacing: 12) {
                    Text("GluCoPilot")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(showWelcome ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.5), value: showWelcome)
                    
                    Text("AI-Powered Diabetes Management")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(showWelcome ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(1.0), value: showWelcome)
                }
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Preparing your health insights...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(showWelcome ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(1.5), value: showWelcome)
                }
            }
        }
        .onAppear {
            isAnimating = true
            showWelcome = true
        }
    }
}

#Preview {
    LaunchScreen()
}
